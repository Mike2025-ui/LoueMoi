from rest_framework import serializers

from .models import Review


class ReviewSerializer(serializers.ModelSerializer):
    """Sortie alignée sur Review.fromJson côté Flutter : property_id, user_id,
    user_name et user_photo sont dérivés de l'utilisateur connecté."""

    property_id = serializers.PrimaryKeyRelatedField(source="property", read_only=True)
    user_id = serializers.PrimaryKeyRelatedField(source="user", read_only=True)
    user_name = serializers.SerializerMethodField()
    user_photo = serializers.SerializerMethodField()

    class Meta:
        model = Review
        fields = [
            "id",
            "property_id",
            "user_id",
            "user_name",
            "user_photo",
            "rating",
            "comment",
            "created_at",
        ]
        read_only_fields = ["id", "created_at"]

    def get_user_name(self, obj):
        return f"{obj.user.first_name} {obj.user.last_name}".strip()

    def get_user_photo(self, obj):
        return obj.user.photo
