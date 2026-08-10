from rest_framework import serializers

from properties.models import Property

from .models import Reservation


class ReservationSerializer(serializers.ModelSerializer):
    # Noms alignés sur Reservation.fromJson côté Flutter
    # (lib/features/reservations/models/reservation.dart) : property_id/user_id,
    # pas les noms de relation Django bruts (property/user).
    property_id = serializers.PrimaryKeyRelatedField(
        source="property", queryset=Property.objects.all()
    )
    user_id = serializers.PrimaryKeyRelatedField(source="user", read_only=True)
    total = serializers.SerializerMethodField()

    class Meta:
        model = Reservation
        fields = [
            "id",
            "property_id",
            "user_id",
            "rent",
            "deposit",
            "advance",
            "total",
            "status",
            "created_at",
        ]
        read_only_fields = ["id", "status", "created_at"]

    def validate_property_id(self, property_obj):
        if property_obj.status != "disponible":
            raise serializers.ValidationError("Cette propriété n'est plus disponible.")
        return property_obj

    def get_total(self, obj):
        return obj.total()
