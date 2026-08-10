from rest_framework import serializers

from .models import Conversation, Message


class MessageSerializer(serializers.ModelSerializer):
    # Noms alignés sur Message.fromJson côté Flutter
    # (lib/features/messaging/models/message.dart) : conversation_id/sender_id/
    # receiver_id, pas les noms de relation Django bruts.
    conversation_id = serializers.PrimaryKeyRelatedField(
        source="conversation", queryset=Conversation.objects.all()
    )
    sender_id = serializers.PrimaryKeyRelatedField(source="sender", read_only=True)
    receiver_id = serializers.PrimaryKeyRelatedField(source="receiver", read_only=True)

    class Meta:
        model = Message
        fields = [
            "id",
            "conversation_id",
            "sender_id",
            "receiver_id",
            "content",
            "created_at",
            "is_read",
        ]
        read_only_fields = ["id", "created_at", "is_read"]


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
        return MessageSerializer(last).data if last else None

    def get_unread_count(self, obj):
        request = self.context.get("request")
        user = request.user if request else None
        return obj.messages.filter(is_read=False).exclude(sender=user).count()
