from rest_framework import serializers

from properties.models import Property

from .models import Reservation


class ReservationClientSerializer(serializers.Serializer):
    """Coordonnées du client qui a réservé — le nom/prénom est exposé au
    propriétaire du bien (agent ou bailleur) pour qu'il sache qui a réservé,
    mais le téléphone/WhatsApp n'est transmis que si le propriétaire dispose
    d'un abonnement Pro actif (ou si le demandeur est le client lui-même)."""

    id = serializers.IntegerField()
    first_name = serializers.CharField()
    last_name = serializers.CharField()
    phone = serializers.SerializerMethodField()
    whatsapp = serializers.SerializerMethodField()

    def _can_view_contact(self, client_user):
        from django.utils import timezone

        request = self.context.get("request")
        req_user = getattr(request, "user", None) if request else None
        if not req_user or not getattr(req_user, "is_authenticated", False):
            return False
        if req_user.id == client_user.id or getattr(req_user, "is_staff", False):
            return True
        cached_sub = getattr(request, "_cached_req_user_has_sub", None)
        if cached_sub is None:
            now = timezone.now()
            cached_sub = bool(
                hasattr(req_user, "subscriptions")
                and req_user.subscriptions.filter(status="active", expires_at__gt=now).exists()
            )
            try:
                setattr(request, "_cached_req_user_has_sub", cached_sub)
            except Exception:
                pass
        return bool(cached_sub)

    def get_phone(self, obj):
        if not self._can_view_contact(obj):
            return ""
        return obj.phone or ""

    def get_whatsapp(self, obj):
        if not self._can_view_contact(obj):
            return ""
        return obj.whatsapp or ""


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
