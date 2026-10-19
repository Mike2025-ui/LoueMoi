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

    # Détection et inversion automatique si JEKO_API_KEY et JEKO_API_KEY_ID ont été intervertis
    # (Ex: la clé secrète commence par 'jeko_' et l'ID est un UUID ou ne commence pas par 'jeko_')
    if api_key_id.startswith("jeko_") and not api_key.startswith("jeko_"):
        logger.warning(
            "JEKO_API_KEY et JEKO_API_KEY_ID semblent inversés dans le fichier .env. "
            "Inversion automatique appliquée pour l'authentification Jèko."
        )
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
    headers = {
        "X-API-KEY": api_key,
        "X-API-KEY-ID": api_key_id,
        "Content-Type": "application/json",
        "Accept": "application/json",
    }

    amount_cents = amount_fcfa * 100

    payload_data = {
        "paymentMethod": payment_method,
        "successUrl": success_url,
        "errorUrl": error_url,
    }
    if payer_phone:
        payload_data["payerPhone"] = payer_phone

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
    req = urllib.request.Request(url, data=data_bytes, headers=headers, method="POST")

    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            resp_data = resp.read().decode("utf-8")
            return json.loads(resp_data)
    except urllib.error.HTTPError as e:
        error_body = e.read().decode("utf-8")
        logger.error(f"Erreur API Jèko ({e.code}): {error_body}")
        if e.code == 401 or "Invalid API key ID" in error_body:
            raise JekoClientError(
                "Erreur Jèko (401 : Invalid API key ID) : La valeur de JEKO_API_KEY_ID dans le fichier .env de votre serveur est incorrecte ou inversée avec JEKO_API_KEY. Vérifiez l'identifiant de clé sur https://jeko.africa."
            )
        raise JekoClientError(f"Erreur Jèko ({e.code}): {error_body}")
    except Exception as e:
        logger.error(f"Erreur réseau Jèko: {e}")
        raise JekoClientError(f"Impossible de contacter la passerelle Jèko: {e}")


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

