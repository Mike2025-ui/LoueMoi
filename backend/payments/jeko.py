import hashlib
import hmac
import json
import logging
import urllib.request
import urllib.error
from django.conf import settings

logger = logging.getLogger(__name__)

JEKO_API_BASE_URL = getattr(settings, "JEKO_API_BASE_URL", "https://api.jeko.africa")


class JekoClientError(Exception):
    pass


def create_payment_request(
    amount_fcfa: int,
    reference: str,
    payment_method: str = "wave",
    success_url: str = "",
    error_url: str = "",
    payer_phone: str = "",
    checkout_url: str = "",
) -> dict:
    """Crée une demande de paiement Jèko Checkout (`POST /partner_api/payment_requests`).

    - `amountCents`: montant en centimes (multiple de 100, min 100).
    - `currency`: 'XOF'
    - `paymentDetails.type`: 'redirect'
    - `paymentDetails.data.paymentMethod`: wave, orange, mtn, moov
    """
    api_key = str(getattr(settings, "JEKO_API_KEY", "")).strip().strip('"').strip("'")
    api_key_id = str(getattr(settings, "JEKO_API_KEY_ID", "")).strip().strip('"').strip("'")
    store_id = str(getattr(settings, "JEKO_STORE_ID", "")).strip().strip('"').strip("'")
    api_url = getattr(settings, "JEKO_API_URL", "https://api.jeko.africa").strip().rstrip("/")
    force_simulation = getattr(settings, "JEKO_SIMULATION_MODE", False)

    # Si l'utilisateur a mis la clé secrète (jeko_...) dans JEKO_API_KEY_ID au lieu de JEKO_API_KEY, on corrige
    if api_key_id.startswith("jeko_") and not api_key.startswith("jeko_"):
        api_key, api_key_id = api_key_id, api_key

    # Mode simulation si les clés Jèko ne sont pas encore configurées ou si le mode simulation est forcé
    if force_simulation or not (api_key and api_key_id and store_id):
        logger.warning(
            "Identifiants Jèko non configurés ou JEKO_SIMULATION_MODE activé. "
            "Utilisation du portail de test de paiement."
        )
        sim_redirect = checkout_url or f"/api/payments/checkout/simulate/?ref={reference}"
        return {
            "id": f"sim_{reference}",
            "storeId": store_id or "00000000-0000-0000-0000-000000000000",
            "reference": reference,
            "status": "pending",
            "type": "redirect",
            "paymentMethod": payment_method,
            "redirectUrl": sim_redirect,
            "simulation": True,
        }

    url = f"{api_url}/partner_api/payment_requests"
    # Ajout des frais de transaction de 1.5% uniquement sur la page de paiement Jèko
    # (1 000 FCFA -> 1 015 FCFA ; 3 000 FCFA -> 3 045 FCFA)
    fee_fcfa = int(round(amount_fcfa * 0.015))
    total_with_fee_fcfa = amount_fcfa + fee_fcfa
    amount_cents = total_with_fee_fcfa * 100

    payload_data = {
        "paymentMethod": payment_method,
        "successUrl": success_url,
        "errorUrl": error_url,
    }

    body = {
        "storeId": store_id,
        "amountCents": amount_cents,
        "currency": "XOF",
        "reference": reference,
        "paymentDetails": {
            "type": "redirect",
            "data": payload_data,
        },
    }

    data_bytes = json.dumps(body).encode("utf-8")

    # Essayer d'abord avec (api_key, api_key_id), puis en cas de 401 avec (api_key_id, api_key)
    key_pairs = [(api_key, api_key_id), (api_key_id, api_key)]
    last_http_err = None
    last_error_body = ""

    for idx, (k_val, kid_val) in enumerate(key_pairs):
        headers = {
            "X-API-KEY": k_val,
            "X-API-KEY-ID": kid_val,
            "Content-Type": "application/json",
            "Accept": "application/json",
        }
        req = urllib.request.Request(url, data=data_bytes, headers=headers, method="POST")
        try:
            with urllib.request.urlopen(req, timeout=15) as resp:
                resp_data = resp.read().decode("utf-8")
                return json.loads(resp_data)
        except urllib.error.HTTPError as e:
            last_http_err = e
            last_error_body = e.read().decode("utf-8")
            if e.code == 401 and idx == 0 and k_val != kid_val:
                logger.warning("401 avec la paire de clés Jèko initiale, tentative automatique en inversant X-API-KEY et X-API-KEY-ID...")
                continue
            break
        except Exception as e:
            logger.error(f"Erreur réseau Jèko: {e}")
            raise JekoClientError(f"Impossible de contacter la passerelle Jèko: {e}")

    e = last_http_err
    error_body = last_error_body
    logger.error(f"Erreur API Jèko ({e.code}): {error_body}")
    if e.code == 401 or "Invalid API key ID" in error_body:
        raise JekoClientError(
            "Erreur Jèko (401 : Invalid API key ID) : La valeur de JEKO_API_KEY_ID dans le fichier .env de votre serveur est incorrecte ou inversée avec JEKO_API_KEY. Vérifiez l'identifiant de clé sur https://jeko.africa."
        )
    if e.code == 422:
        try:
            err_json = json.loads(error_body)
            errors_list = (
                (err_json.get("extras") or {}).get("errors")
                or err_json.get("errors")
                or []
            )
            if errors_list and isinstance(errors_list, list):
                msgs = [
                    f"{item.get('field', '')}: {item.get('message', '')}".strip(": ")
                    for item in errors_list
                    if isinstance(item, dict)
                ]
                if msgs:
                    raise JekoClientError(f"Erreur de validation Jèko (422): {', '.join(msgs)}")
            if err_json.get("message"):
                raise JekoClientError(f"Erreur de validation Jèko (422): {err_json['message']}")
        except JekoClientError:
            raise
        except Exception:
            pass
    raise JekoClientError(f"Erreur Jèko ({e.code}): {error_body}")


def verify_webhook_signature(raw_body: bytes, received_signature: str) -> bool:
    """Vérifie l'authenticité d'un webhook Jèko via l'en-tête Jeko-Signature.
    HMAC-SHA256 du raw body avec JEKO_WEBHOOK_SECRET, comparé en temps constant."""
    secret = str(getattr(settings, "JEKO_WEBHOOK_SECRET", "")).strip().strip('"').strip("'")
    if not secret:
        logger.error("JEKO_WEBHOOK_SECRET non configuré dans les settings.")
        return False

    if not received_signature:
        return False

    expected_signature = hmac.new(
        secret.encode("utf-8"),
        raw_body,
        hashlib.sha256,
    ).hexdigest()

    return hmac.compare_digest(expected_signature.lower(), received_signature.lower())


def get_payment_request_status(payment_request_id: str) -> dict | None:
    """Interroge l'API Jèko pour obtenir le statut temps réel d'une demande de paiement :
    GET https://api.jeko.africa/partner_api/payment_requests/{id}
    """
    if not payment_request_id or payment_request_id.startswith("sim_"):
        return None

    api_key = str(getattr(settings, "JEKO_API_KEY", "")).strip().strip('"').strip("'")
    api_key_id = str(getattr(settings, "JEKO_API_KEY_ID", "")).strip().strip('"').strip("'")
    api_url = getattr(settings, "JEKO_API_URL", "https://api.jeko.africa").strip().rstrip("/")

    if api_key_id.startswith("jeko_") and not api_key.startswith("jeko_"):
        api_key, api_key_id = api_key_id, api_key

    if not (api_key and api_key_id):
        return None

    url = f"{api_url}/partner_api/payment_requests/{payment_request_id}"
    for idx, (k_val, kid_val) in enumerate([(api_key, api_key_id), (api_key_id, api_key)]):
        headers = {
            "X-API-KEY": k_val,
            "X-API-KEY-ID": kid_val,
            "Accept": "application/json",
        }
        req = urllib.request.Request(url, headers=headers, method="GET")
        try:
            with urllib.request.urlopen(req, timeout=10) as resp:
                data = json.loads(resp.read().decode("utf-8"))
                return data
        except urllib.error.HTTPError as e:
            if e.code == 401 and idx == 0 and k_val != kid_val:
                continue
            logger.warning(f"Échec de vérification du paiement Jèko ({payment_request_id}): {e}")
            return None
        except Exception as e:
            logger.warning(f"Échec de vérification du paiement Jèko ({payment_request_id}): {e}")
            return None
    return None


def extract_jeko_status(jeko_data: dict | None) -> str:
    if not jeko_data or not isinstance(jeko_data, dict):
        return ""
    raw_status = (
        jeko_data.get("status")
        or (jeko_data.get("data") or {}).get("status")
        or (jeko_data.get("transactionDetails") or {}).get("status")
        or (jeko_data.get("paymentDetails") or {}).get("status")
        or ""
    )
    return str(raw_status).strip().lower()


def is_jeko_status_success(tx_status: str) -> bool:
    return tx_status in (
        "success",
        "successful",
        "succeeded",
        "completed",
        "paid",
        "approved",
        "validated",
        "confirmed",
        "done",
    )


def is_jeko_status_failed(tx_status: str) -> bool:
    return tx_status in (
        "error",
        "failed",
        "cancelled",
        "canceled",
        "declined",
        "rejected",
    )


