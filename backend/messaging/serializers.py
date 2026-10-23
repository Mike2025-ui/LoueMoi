from django.contrib.auth import get_user_model
from django.urls import reverse
from rest_framework import serializers

from .models import Conversation, Message

User = get_user_model()


class MessageSerializer(serializers.ModelSerializer):
    # Noms alignés sur Message.fromJson côté Flutter
    # (lib/features/messaging/models/message.dart) : conversation_id/sender_id/
    # receiver_id, pas les noms de relation Django bruts.
    conversation_id = serializers.PrimaryKeyRelatedField(
        source="conversation", queryset=Conversation.objects.all()
    )
    sender_id = serializers.PrimaryKeyRelatedField(source="sender", read_only=True)
    receiver_id = serializers.PrimaryKeyRelatedField(source="receiver", read_only=True)
    # `attachment` reste write_only : jamais exposé comme URL MEDIA_URL
    # brute (publique, non protégée). Le client télécharge toujours via
    # `attachment_url`, qui pointe vers un endpoint authentifié.
    attachment_url = serializers.SerializerMethodField()

    class Meta:
        model = Message
        fields = [
            "id",
            "conversation_id",
            "sender_id",
            "receiver_id",
            "content",
            "attachment",
            "attachment_type",
            "duration",
            "attachment_url",
            "created_at",
            "is_read",
        ]
        read_only_fields = ["id", "created_at", "is_read", "attachment_url"]
        extra_kwargs = {"attachment": {"write_only": True, "required": False}}

    def get_attachment_url(self, obj):
        if not obj.attachment:
            return None
        from urllib.parse import urlencode
        from django.core.signing import TimestampSigner

        request = self.context.get("request")
        path = reverse("message-attachment", args=[obj.pk])
        signer = TimestampSigner(salt="messaging.attachment")
        sig = signer.sign(str(obj.pk))
        signed_path = f"{path}?{urlencode({'sig': sig})}"
        return request.build_absolute_uri(signed_path) if request else signed_path

    def validate(self, attrs):
        import os
        import uuid
        from PIL import Image

        content = attrs.get("content", "") or ""
        attachment = attrs.get("attachment")
        attachment_type = attrs.get("attachment_type", Message.TYPE_TEXT)
        if not content.strip() and not attachment:
            raise serializers.ValidationError(
                "Un message doit contenir du texte ou une pièce jointe."
            )
        if attachment:
            if attachment_type == Message.TYPE_TEXT:
                raise serializers.ValidationError(
                    {"attachment_type": "Précisez le type de la pièce jointe (image/video/audio)."}
                )
            ext = os.path.splitext(attachment.name or "")[1].lower()
            allowed_by_type = {
                Message.TYPE_IMAGE: ({".jpg", ".jpeg", ".png", ".webp"}, 10 * 1024 * 1024),
                Message.TYPE_VIDEO: ({".mp4", ".mov", ".webm"}, 50 * 1024 * 1024),
                Message.TYPE_AUDIO: ({".m4a", ".aac", ".mp3", ".wav", ".ogg", ".opus"}, 15 * 1024 * 1024),
            }
            if attachment_type not in allowed_by_type:
                raise serializers.ValidationError({"attachment_type": "Type de pièce jointe invalide."})

            allowed_exts, max_bytes = allowed_by_type[attachment_type]
            if ext not in allowed_exts:
                raise serializers.ValidationError(
                    {"attachment": f"Extension de fichier non autorisée ({ext})."}
                )
            if attachment.size > max_bytes:
                max_mb = max_bytes // (1024 * 1024)
                raise serializers.ValidationError(
                    {"attachment": f"Le fichier dépasse la taille maximale autorisée ({max_mb} Mo)."}
                )
            if attachment_type == Message.TYPE_IMAGE:
                try:
                    header = attachment.read(16)
                    attachment.seek(0)
                    is_valid_magic = (
                        header.startswith(b"\xff\xd8\xff")
                        or header.startswith(b"\x89PNG\r\n\x1a\n")
                        or (header.startswith(b"RIFF") and b"WEBP" in header)
                    )
                    if not is_valid_magic:
                        raise ValueError("Invalid magic bytes")
                except Exception:
                    raise serializers.ValidationError(
                        {"attachment": "Le fichier image est invalide ou corrompu."}
                    )
            attachment.name = f"{uuid.uuid4().hex[:16]}{ext}"
        return attrs


class ConversationSerializer(serializers.ModelSerializer):
    participant_name = serializers.SerializerMethodField()
    participant_photo = serializers.SerializerMethodField()
    last_message = serializers.SerializerMethodField()
    unread_count = serializers.SerializerMethodField()

    class Meta:
        model = Conversation
        fields = [
            "id",
            "client",
            "agent",
            "property",
            "participant_name",
            "participant_photo",
            "last_message",
            "unread_count",
            "created_at",
        ]
        read_only_fields = ["id", "client", "created_at"]
        # Pas de validation stricte d'unicité ici : la vue fait un
        # get_or_create (client, agent, property) pour renvoyer la
        # conversation existante plutôt que de rejeter une 2e tentative.
        validators = []

    def validate_agent(self, value):
        # Le "destinataire agent" d'une conversation doit être un
        # propriétaire d'annonce (agent OU bailleur — même paire de rôles
        # que Property.agent.limit_choices_to, colonne "agent" conservée
        # pour compatibilité mais jamais restreinte à ce seul rôle). Sans
        # ça, "Contacter l'agent" échouait pour TOUTE annonce publiée par un
        # bailleur (property.agent est alors un bailleur), et "Rechercher un
        # propriétaire" (contacter un bailleur trouvé via /api/bailleurs/)
        # aurait échoué de la même façon. Empêche seulement de créer une
        # conversation avec un simple client placé dans ce slot.
        if value.role not in (User.ROLE_AGENT, User.ROLE_BAILLEUR):
            raise serializers.ValidationError(
                "Ce destinataire n'est pas un agent immobilier ou un bailleur."
            )
        return value

    def _other_participant(self, obj):
        request = self.context.get("request")
        user = request.user if request else None
        return obj.agent if user == obj.client else obj.client

    def get_participant_name(self, obj):
        participant = self._other_participant(obj)
        return f"{participant.first_name} {participant.last_name}".strip()

    def get_participant_photo(self, obj):
        return self._other_participant(obj).photo

    def get_last_message(self, obj):
        last = obj.messages.order_by("-created_at").first()
        return MessageSerializer(last, context=self.context).data if last else None

    def get_unread_count(self, obj):
        request = self.context.get("request")
        user = request.user if request else None
        return obj.messages.filter(is_read=False).exclude(sender=user).count()
