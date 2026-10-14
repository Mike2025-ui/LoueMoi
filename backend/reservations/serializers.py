from rest_framework import serializers

from properties.models import Property

from .models import Reservation


class ReservationClientSerializer(serializers.Serializer):
    """Coordonnées publiques du client qui a réservé — exposées au
    propriétaire du bien (agent ou bailleur) pour qu'il sache qui a
    réservé. Jamais de champ sensible (password, tokens...) : mêmes champs
    que la fiche agent publique (AgentSearchSerializer)."""

    id = serializers.IntegerField()
    first_name = serializers.CharField()
    last_name = serializers.CharField()
    phone = serializers.CharField()
    whatsapp = serializers.CharField()


class ReservationSerializer(serializers.ModelSerializer):
    # Noms alignés sur Reservation.fromJson côté Flutter
    # (lib/features/reservations/models/reservation.dart) : property_id/user_id,
    # pas les noms de relation Django bruts (property/user).
    property_id = serializers.PrimaryKeyRelatedField(
        source="property", queryset=Property.objects.all()
    )
    user_id = serializers.PrimaryKeyRelatedField(source="user", read_only=True)
    total = serializers.SerializerMethodField()
    # Qui a réservé — voir le cahier des charges "RÉSERVATIONS — VOIR QUI A
    # RÉSERVÉ" : le queryset (ReservationViewSet.get_queryset) est déjà le
    # seul rempart de permission nécessaire ici (un agent/bailleur ne reçoit
    # dans ses résultats que les réservations de ses propres biens), donc ce
    # champ peut être renvoyé sans condition supplémentaire.
    client = ReservationClientSerializer(source="user", read_only=True)

    class Meta:
        model = Reservation
        fields = [
            "id",
            "property_id",
            "user_id",
            "client",
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
