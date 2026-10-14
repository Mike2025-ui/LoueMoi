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
        request = self.context.get("request")
        path = reverse("message-attachment", args=[obj.pk])
        return request.build_absolute_uri(path) if request else path

    def validate(self, attrs):
        content = attrs.get("content", "") or ""
        attachment = attrs.get("attachment")
        attachment_type = attrs.get("attachment_type", Message.TYPE_TEXT)
        if not content.strip() and not attachment:
            raise serializers.ValidationError(
                "Un message doit contenir du texte ou une pièce jointe."
            )
        if attachment and attachment_type == Message.TYPE_TEXT:
            raise serializers.ValidationError(
                {"attachment_type": "Précisez le type de la pièce jointe (image/video/audio)."}
            )
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
