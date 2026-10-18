import uuid
from datetime import timedelta
from django.conf import settings
from django.db import models
from django.utils import timezone


class Subscription(models.Model):
    """Abonnement mensuel LoueMoi géré via Jèko Checkout.

    Règles métier :
    - Client : 1 000 FCFA / mois
    - Agent & Bailleur : 3 000 FCFA / mois
    - Si l'agent/bailleur a un abonnement actif : les clients peuvent le contacter GRATUITEMENT.
    - Si l'agent/bailleur n'a PAS d'abonnement : le client doit obligatoirement avoir un abonnement actif pour le contacter.
    - Les réservations sont gratuites mais l'agent/bailleur ne peut pas contacter/discuter avec le client sans abonnement.
    - Seuls les utilisateurs possédant un abonnement bénéficient automatiquement du badge de vérification.
    """

    PLAN_CLIENT = "client"
    PLAN_PRO = "pro"
    PLAN_CHOICES = [
        (PLAN_CLIENT, "Client (1 000 FCFA / mois)"),
        (PLAN_PRO, "Bailleur / Agent (3 000 FCFA / mois)"),
    ]

    PRICES = {
        PLAN_CLIENT: 1000,
        PLAN_PRO: 3000,
    }

    STATUS_PENDING = "pending"
    STATUS_ACTIVE = "active"
    STATUS_EXPIRED = "expired"
    STATUS_CANCELLED = "cancelled"
    STATUS_CHOICES = [
        (STATUS_PENDING, "En attente"),
        (STATUS_ACTIVE, "Actif"),
        (STATUS_EXPIRED, "Expiré"),
        (STATUS_CANCELLED, "Annulé"),
    ]

    METHOD_WAVE = "wave"
    METHOD_ORANGE = "orange"
    METHOD_MTN = "mtn"
    METHOD_MOOV = "moov"
    METHOD_DJAMO = "djamo"
    PAYMENT_METHOD_CHOICES = [
        (METHOD_WAVE, "Wave Mobile Money"),
        (METHOD_ORANGE, "Orange Money"),
        (METHOD_MTN, "MTN Mobile Money"),
        (METHOD_MOOV, "Moov Money"),
        (METHOD_DJAMO, "Djamo"),
    ]

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="subscriptions",
    )
    plan = models.CharField(max_length=20, choices=PLAN_CHOICES)
    amount = models.PositiveIntegerField(help_text="Montant en FCFA (1000 ou 3000)")
    payment_method = models.CharField(
        max_length=20,
        choices=PAYMENT_METHOD_CHOICES,
        default=METHOD_WAVE,
    )
    reference = models.CharField(max_length=100, unique=True, db_index=True)
    jeko_payment_request_id = models.CharField(max_length=100, blank=True, default="")
    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default=STATUS_PENDING,
    )
    started_at = models.DateTimeField(null=True, blank=True)
    expires_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]
        verbose_name = "Abonnement"
        verbose_name_plural = "Abonnements"

    def __str__(self):
        return f"{self.user} - {self.get_plan_display()} ({self.get_status_display()})"

    @property
    def is_currently_active(self):
        now = timezone.now()
        return (
            self.status == self.STATUS_ACTIVE
            and self.expires_at is not None
            and self.expires_at > now
        )

    @property
    def days_remaining(self):
        if not self.is_currently_active or not self.expires_at:
            return 0
        diff = self.expires_at - timezone.now()
        return max(0, diff.days)

    def activate_for_30_days(self):
        """Active ou renouvelle l'abonnement pour une période de 30 jours,
        et attribue automatiquement le badge de vérification."""
        now = timezone.now()
        if self.expires_at and self.expires_at > now:
            self.expires_at = self.expires_at + timedelta(days=30)
        else:
            self.started_at = now
            self.expires_at = now + timedelta(days=30)

        self.status = self.STATUS_ACTIVE
        self.save(update_fields=["status", "started_at", "expires_at", "updated_at"])

        # Attribution automatique du badge de vérification (agents et bailleurs abonnés)
        user = self.user
        if user.role in (user.ROLE_AGENT, user.ROLE_BAILLEUR):
            user.is_verified = True
            user.save(update_fields=["is_verified"])

            if hasattr(user, "agent_profile"):
                profile = user.agent_profile
                profile.is_verified = True
                profile.save(update_fields=["is_verified"])
