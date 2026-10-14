from django.conf import settings
from django.db import models

from messaging.models import Conversation
from properties.models import Property
from reservations.models import Reservation


class Notification(models.Model):
    """Notification persistante — l'historique consultable via
    GET /api/notifications/ même après fermeture de l'app, distinct mais lié
    au push FCM éventuellement envoyé au moment de sa création (voir
    notifications.services.NotificationService)."""

    TYPE_RESERVATION_CREATED = "reservation_created"
    TYPE_RESERVATION_CONFIRMED = "reservation_confirmed"
    TYPE_RESERVATION_CANCELLED = "reservation_cancelled"
    TYPE_NEW_MESSAGE = "new_message"
    TYPE_NEW_REVIEW = "new_review"
    TYPE_PROPERTY_AVAILABLE = "property_available"
    TYPE_NEW_RESERVATION = "new_reservation"
    TYPE_PROPERTY_OCCUPIED = "property_occupied"
    TYPE_CHOICES = [
        (TYPE_RESERVATION_CREATED, "Réservation envoyée"),
        (TYPE_RESERVATION_CONFIRMED, "Réservation confirmée"),
        (TYPE_RESERVATION_CANCELLED, "Réservation annulée"),
        (TYPE_NEW_MESSAGE, "Nouveau message"),
        (TYPE_NEW_REVIEW, "Nouvel avis"),
        (TYPE_PROPERTY_AVAILABLE, "Bien disponible"),
        (TYPE_NEW_RESERVATION, "Nouvelle réservation"),
        (TYPE_PROPERTY_OCCUPIED, "Bien occupé"),
    ]

    recipient = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="notifications"
    )
    title = models.CharField(max_length=200)
    body = models.TextField(blank=True)
    type = models.CharField(max_length=30, choices=TYPE_CHOICES)
    # Payload structuré pour la navigation au clic côté Flutter (jamais du
    # texte libre à parser) — ex: {"conversation_id": "12"}.
    data = models.JSONField(default=dict, blank=True)

    # Relations optionnelles, pratiques pour filtrer/afficher côté admin —
    # SET_NULL : la notification reste dans l'historique même si l'objet
    # lié est supprimé par la suite.
    property = models.ForeignKey(
        Property, on_delete=models.SET_NULL, null=True, blank=True, related_name="notifications"
    )
    reservation = models.ForeignKey(
        Reservation, on_delete=models.SET_NULL, null=True, blank=True,
        related_name="notifications",
    )
    conversation = models.ForeignKey(
        Conversation, on_delete=models.SET_NULL, null=True, blank=True,
        related_name="notifications",
    )

    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.type} → {self.recipient}"


class DeviceToken(models.Model):
    """Un token FCM par appareil. Un utilisateur peut en avoir plusieurs
    (téléphone Android, iPhone...) — jamais limité à un seul."""

    PLATFORM_ANDROID = "android"
    PLATFORM_IOS = "ios"
    PLATFORM_CHOICES = [
        (PLATFORM_ANDROID, "Android"),
        (PLATFORM_IOS, "iOS"),
    ]

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="device_tokens"
    )
    token = models.CharField(max_length=255, unique=True)
    platform = models.CharField(max_length=10, choices=PLATFORM_CHOICES)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-updated_at"]

    def __str__(self):
        return f"{self.user} — {self.platform} ({'actif' if self.is_active else 'inactif'})"
