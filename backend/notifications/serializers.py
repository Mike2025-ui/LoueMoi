from rest_framework import serializers

from .models import DeviceToken, Notification


class NotificationSerializer(serializers.ModelSerializer):
    property_id = serializers.PrimaryKeyRelatedField(source="property", read_only=True)
    reservation_id = serializers.PrimaryKeyRelatedField(source="reservation", read_only=True)
    conversation_id = serializers.PrimaryKeyRelatedField(source="conversation", read_only=True)

    class Meta:
        model = Notification
        fields = [
            "id",
            "title",
            "body",
            "type",
            "data",
            "property_id",
            "reservation_id",
            "conversation_id",
            "is_read",
            "created_at",
        ]
        # Entièrement en lecture seule : une notification est créée par la
        # logique métier (NotificationService), jamais via une API publique
        # (voir la règle "un agent ne peut jamais créer manuellement une
        # notification pour lui-même").
        read_only_fields = fields


class DeviceTokenSerializer(serializers.ModelSerializer):
    class Meta:
        model = DeviceToken
        fields = ["id", "token", "platform", "is_active", "created_at", "updated_at"]
        read_only_fields = ["id", "is_active", "created_at", "updated_at"]
        # write_only : le token FCM brut ne doit jamais être renvoyé dans une
        # réponse API (voir aussi DeviceTokenAdmin.masked_token, qui applique
        # la même règle côté Django Admin) — seul le sender (Firebase) et
        # l'appareil qui l'a enregistré ont besoin de le connaître.
        extra_kwargs = {"token": {"write_only": True}}
