from django.conf import settings
from django.db import models

from properties.models import Property


class Conversation(models.Model):
    """Fil de discussion entre un client et un agent, correspondant à
    Conversation côté Flutter (lib/features/messaging/models/message.dart).
    Le champ `client` n'est pas restreint au rôle "client" : un bailleur qui
    contacte un agent occupe ce même slot (initiateur de la conversation),
    exactement comme un client qui contacte l'agent d'une annonce — c'est un
    seul système de messagerie, jamais dupliqué."""

    client = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="conversations_as_client"
    )
    agent = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="conversations_as_agent"
    )
    property = models.ForeignKey(
        Property, on_delete=models.SET_NULL, null=True, blank=True, related_name="conversations"
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ("client", "agent", "property")
        ordering = ["-created_at"]

    def __str__(self):
        return f"{self.client} ↔ {self.agent}"


class Message(models.Model):
    """Correspond à Message côté Flutter. Supporte texte ET pièces jointes
    (image/vidéo/audio) — un seul modèle, jamais un système parallèle par
    type de contenu."""

    TYPE_TEXT = "text"
    TYPE_IMAGE = "image"
    TYPE_VIDEO = "video"
    TYPE_AUDIO = "audio"
    ATTACHMENT_TYPE_CHOICES = [
        (TYPE_TEXT, "Texte"),
        (TYPE_IMAGE, "Image"),
        (TYPE_VIDEO, "Vidéo"),
        (TYPE_AUDIO, "Audio"),
    ]

    conversation = models.ForeignKey(Conversation, on_delete=models.CASCADE, related_name="messages")
    sender = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="sent_messages"
    )
    receiver = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="received_messages"
    )
    # blank=True : un message peut être uniquement une pièce jointe, sans
    # texte d'accompagnement (voir MessageSerializer.validate — au moins
    # l'un des deux, content ou attachment, reste obligatoire).
    content = models.TextField(blank=True)

    # Stocké via MEDIA_ROOT (default_storage), jamais en base — seul le
    # chemin est en base. Jamais servi via l'URL MEDIA_URL publique : voir
    # MessageAttachmentDownloadView (téléchargement authentifié, réservé aux
    # participants de la conversation).
    attachment = models.FileField(upload_to="messages/%Y/%m/", null=True, blank=True)
    attachment_type = models.CharField(
        max_length=10, choices=ATTACHMENT_TYPE_CHOICES, default=TYPE_TEXT
    )
    # Durée en secondes — pertinent uniquement pour audio/vidéo.
    duration = models.PositiveIntegerField(null=True, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    is_read = models.BooleanField(default=False)

    class Meta:
        ordering = ["created_at"]

    def __str__(self):
        return f"{self.sender} → {self.receiver}: {self.content[:30]}"
