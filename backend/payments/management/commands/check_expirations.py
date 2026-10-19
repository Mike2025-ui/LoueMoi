import logging
from datetime import timedelta
from django.core.management.base import BaseCommand
from django.utils import timezone

from notifications.models import Notification
from notifications.services import NotificationService
from payments.models import Subscription

logger = logging.getLogger(__name__)


class Command(BaseCommand):
    help = (
        "Vérifie les expirations des abonnements LoueMoi, alerte les utilisateurs "
        "5 jours avant expiration et révoque le badge et les accès à échéance."
    )

    def handle(self, *args, **options):
        now = timezone.now()
        warning_window = now + timedelta(days=5)

        # 1. Alerte 5 jours avant expiration
        expiring_subs = Subscription.objects.filter(
            status=Subscription.STATUS_ACTIVE,
            expires_at__gt=now,
            expires_at__lte=warning_window,
            expiry_warning_sent=False,
        ).select_related("user")

        warn_count = 0
        for sub in expiring_subs:
            days_left = max(1, (sub.expires_at - now).days)
            expiry_str = sub.expires_at.strftime("%d/%m/%Y")
            NotificationService.notify(
                recipient=sub.user,
                notif_type=Notification.TYPE_SUBSCRIPTION_EXPIRING,
                title="Abonnement expirant bientôt",
                body=(
                    f"Votre abonnement LoueMoi expire dans {days_left} jour(s) (le {expiry_str}). "
                    "Renouvelez-le dès maintenant pour conserver vos accès et votre badge vérifié."
                ),
                data={
                    "type": "subscription_expiring",
                    "subscription_id": sub.id,
                    "reference": sub.reference,
                    "expires_at": sub.expires_at.isoformat(),
                },
            )
            sub.expiry_warning_sent = True
            sub.save(update_fields=["expiry_warning_sent"])
            warn_count += 1
            logger.info(f"Alerte expiration envoyée à {sub.user.phone} ({days_left} jours restants).")

        # 2. Traitement des abonnements expirés
        expired_subs = Subscription.objects.filter(
            status=Subscription.STATUS_ACTIVE,
            expires_at__lte=now,
        ).select_related("user")

        expire_count = 0
        for sub in expired_subs:
            sub.expire_and_revoke()
            NotificationService.notify(
                recipient=sub.user,
                notif_type=Notification.TYPE_SUBSCRIPTION_EXPIRED,
                title="Abonnement expiré",
                body=(
                    "Votre abonnement LoueMoi a expiré. Vous avez perdu vos accès privilégiés "
                    "et votre badge certifié. Réabonnez-vous pour les réactiver immédiatement."
                ),
                data={
                    "type": "subscription_expired",
                    "subscription_id": sub.id,
                    "reference": sub.reference,
                },
            )
            expire_count += 1
            logger.info(f"Abonnement expiré et badge révoqué pour {sub.user.phone}.")

        self.stdout.write(
            self.style.SUCCESS(
                f"Traitement terminé : {warn_count} alerte(s) 5 jours envoyée(s), "
                f"{expire_count} abonnement(s) expiré(s) révoqué(s)."
            )
        )

