"""Abstraction d'envoi de SMS — AUCUN FOURNISSEUR RÉEL N'EST CONFIGURÉ dans
ce projet à ce jour (audité : aucune trace de Twilio, Africa's Talking,
Orange SMS API ou équivalent dans requirements.txt ni les settings).

Pour brancher un vrai fournisseur avant la mise en production du mot de
passe oublié :
  1. Implémenter SmsProvider.send() dans une nouvelle classe (ex.
     TwilioSmsProvider), en lisant ses identifiants depuis une variable
     d'environnement (jamais commitée), même principe que
     FIREBASE_CREDENTIALS_JSON pour les notifications push.
  2. Faire retourner cette classe par get_sms_provider().
Rien d'autre à changer : PasswordResetRequestView n'appelle que
get_sms_provider().send(...), jamais un fournisseur en dur.
"""

import logging

from django.conf import settings

logger = logging.getLogger(__name__)


class SmsProvider:
    def send(self, phone, message):
        raise NotImplementedError


class LoggingSmsProvider(SmsProvider):
    """Bouchon de développement : n'envoie AUCUN SMS réel, ne prétend jamais
    le contraire. En DEBUG, journalise le message pour permettre de tester
    le flux OTP sans fournisseur — jamais en production (DEBUG=False), où
    le contenu (donc le code OTP) n'est jamais journalisé, conformément à
    l'exigence "ne jamais afficher l'OTP dans les logs de production"."""

    def send(self, phone, message):
        if settings.DEBUG:
            logger.warning(
                "[SMS NON ENVOYÉ — AUCUN FOURNISSEUR CONFIGURÉ] destinataire=%s message=%s",
                phone,
                message,
            )
        else:
            logger.error(
                "Tentative d'envoi SMS à %s sans fournisseur configuré — aucun SMS envoyé, "
                "voir accounts/sms.py pour brancher un vrai fournisseur.",
                phone,
            )


def get_sms_provider() -> SmsProvider:
    return LoggingSmsProvider()
