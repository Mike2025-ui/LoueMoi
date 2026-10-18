"""Module d'envoi de SMS LoueMoi — Intégration de la passerelle OTP IKKODI (Ikoddi).

Prend en charge la passerelle SMS Ikoddi pour l'authentification et les codes
OTP de réinitialisation de mot de passe ("Mot de passe oublié").
En l'absence de clé API (mode dev/test), bascule automatiquement sur LoggingSmsProvider.

Configuration attendue (via variables d'environnement sur le serveur de production) :
  - IKODDI_API_KEY (ou IKKODI_API_KEY) : clé API secrète Ikoddi
  - IKODDI_SENDER_ID (ou IKKODI_SENDER_ID) : nom d'expéditeur (ex. "LoueMoi", max 11 car.)
  - IKODDI_API_URL (ou IKKODI_API_URL) : URL du endpoint (défaut : "https://api.ikoddi.com/v1/sms/send")
"""

import json
import logging
import os
import re
import urllib.error
import urllib.request

from django.conf import settings

logger = logging.getLogger(__name__)


def normalize_phone_number(phone: str) -> str:
    """Normalise un numéro de téléphone au format international attendu par les passerelles SMS.

    Exemples :
      - "07 01 02 03 04" -> "+2250701020304" (format 10 chiffres Côte d'Ivoire)
      - "+225 0701020304" -> "+2250701020304"
      - "2250701020304" -> "+2250701020304"
      - "002250701020304" -> "+2250701020304"
    """
    if not phone:
        return ""

    raw = phone.strip()
    # Remplacer le préfixe international 00 par +
    if raw.startswith("00"):
        raw = "+" + raw[2:]

    # Retirer les espaces, tirets, parenthèses, points
    cleaned = re.sub(r"[^\d+]", "", raw)

    # Déjà au format +...
    if cleaned.startswith("+"):
        return cleaned

    # Format 225... sans le +
    if cleaned.startswith("225") and len(cleaned) >= 11:
        return f"+{cleaned}"

    # Numéro national ivoirien (10 chiffres commençant par 0)
    if len(cleaned) == 10 and cleaned.startswith("0"):
        return f"+225{cleaned}"

    # Numéro sans indicatif
    return f"+{cleaned}" if cleaned else ""


def _mask_phone(phone: str) -> str:
    """Masque un numéro de téléphone pour les logs sécurisés."""
    if not phone or len(phone) < 6:
        return "***"
    return f"{phone[:4]}****{phone[-2:]}"


class SmsProvider:
    def send(self, phone: str, message: str) -> bool:
        raise NotImplementedError


class LoggingSmsProvider(SmsProvider):
    """Bouchon de développement : n'envoie AUCUN SMS réel.
    En DEBUG, journalise le message pour permettre de tester le flux OTP sans fournisseur.
    En production (DEBUG=False), le contenu du code OTP n'est JAMAIS journalisé.
    """

    def send(self, phone: str, message: str) -> bool:
        if settings.DEBUG:
            logger.warning(
                "[SMS NON ENVOYÉ — AUCUN FOURNISSEUR CONFIGURÉ] destinataire=%s message=%s",
                phone,
                message,
            )
        else:
            logger.error(
                "Tentative d'envoi SMS à %s sans fournisseur configuré — aucun SMS envoyé, "
                "définissez IKODDI_API_KEY sur le serveur pour activer l'envoi réel.",
                _mask_phone(phone),
            )
        return True


class IkoddiSmsProvider(SmsProvider):
    """Fournisseur SMS officiel IKKODI (Ikoddi).

    Documentation d'intégration :
      Endpoint : POST https://api.ikoddi.com/v1/sms/send
      Headers  : Authorization: Bearer <API_KEY>, Content-Type: application/json
      Body     : {"to": "+225...", "message": "...", "sender": "LoueMoi"}
    """

    DEFAULT_API_URL = "https://api.ikoddi.com/v1/sms/send"
    DEFAULT_SENDER_ID = "LoueMoi"

    def __init__(
        self,
        api_key: str,
        sender_id: str | None = None,
        api_url: str | None = None,
        timeout: int = 10,
    ):
        self.api_key = api_key.strip()
        self.sender_id = (sender_id or self.DEFAULT_SENDER_ID).strip()[:11]
        self.api_url = (api_url or self.DEFAULT_API_URL).strip()
        self.timeout = timeout

    def send(self, phone: str, message: str) -> bool:
        normalized_phone = normalize_phone_number(phone)
        masked_phone = _mask_phone(normalized_phone)

        payload = {
            "to": normalized_phone,
            "recipient": normalized_phone,
            "message": message,
            "sender": self.sender_id,
            "from": self.sender_id,
        }

        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json",
            "Accept": "application/json",
            "User-Agent": "LoueMoi-Backend/1.0",
        }

        try:
            data = json.dumps(payload).encode("utf-8")
            req = urllib.request.Request(
                self.api_url,
                data=data,
                headers=headers,
                method="POST",
            )
            with urllib.request.urlopen(req, timeout=self.timeout) as resp:
                status_code = resp.status
                body = resp.read().decode("utf-8", errors="replace")
                logger.info(
                    "SMS OTP Ikoddi envoyé avec succès vers %s (HTTP %s, sender=%s)",
                    masked_phone,
                    status_code,
                    self.sender_id,
                )
                return True

        except urllib.error.HTTPError as err:
            err_body = err.read().decode("utf-8", errors="replace") if err.fp else ""
            logger.error(
                "Erreur HTTP lors de l'envoi SMS Ikoddi vers %s : HTTP %s — %s",
                masked_phone,
                err.code,
                err_body[:200],
            )
            return False

        except urllib.error.URLError as err:
            logger.error(
                "Erreur de connexion à l'API Ikoddi vers %s : %s",
                masked_phone,
                err.reason,
            )
            return False

        except Exception as err:
            logger.error(
                "Exception inattendue lors de l'envoi SMS Ikoddi vers %s : %s",
                masked_phone,
                str(err),
            )
            return False


def get_sms_provider() -> SmsProvider:
    """Retourne l'instance SmsProvider active.

    Si une clé API IKODDI / IKKODI est configurée (settings Django ou variable
    d'environnement), retourne IkoddiSmsProvider. Sinon, retourne LoggingSmsProvider.
    """
    api_key = (
        getattr(settings, "IKODDI_API_KEY", "")
        or os.environ.get("IKODDI_API_KEY", "")
        or os.environ.get("IKKODI_API_KEY", "")
    ).strip()

    if api_key:
        sender_id = (
            getattr(settings, "IKODDI_SENDER_ID", "")
            or os.environ.get("IKODDI_SENDER_ID", "")
            or os.environ.get("IKKODI_SENDER_ID", "")
            or IkoddiSmsProvider.DEFAULT_SENDER_ID
        ).strip()
        api_url = (
            getattr(settings, "IKODDI_API_URL", "")
            or os.environ.get("IKODDI_API_URL", "")
            or os.environ.get("IKKODI_API_URL", "")
            or IkoddiSmsProvider.DEFAULT_API_URL
        ).strip()
        return IkoddiSmsProvider(api_key=api_key, sender_id=sender_id, api_url=api_url)

    return LoggingSmsProvider()
