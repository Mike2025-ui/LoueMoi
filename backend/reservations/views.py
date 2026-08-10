from django.db import transaction
from django.db.models import Q
from rest_framework import permissions, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response

from .models import Reservation
from .serializers import ReservationSerializer


class ReservationViewSet(viewsets.ModelViewSet):
    """/api/reservations/ — correspond à Reservation côté Flutter. À la
    création, la propriété réservée passe automatiquement au statut
    "occupee" (même règle métier que l'écran de détail Flutter, qui masque
    le bouton Réserver pour les biens occupés)."""

    serializer_class = ReservationSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if user.is_staff:
            return Reservation.objects.all()
        if user.role == user.ROLE_AGENT:
            # Un agent voit ses propres réservations + celles faites sur ses
            # biens (jamais celles des biens d'un autre agent).
            return Reservation.objects.filter(Q(user=user) | Q(property__agent=user)).distinct()
        return Reservation.objects.filter(user=user)

    @transaction.atomic
    def perform_create(self, serializer):
        reservation = serializer.save(user=self.request.user, status="enCours")
        property_obj = reservation.property
        property_obj.status = "occupee"
        property_obj.save(update_fields=["status"])

    @action(detail=True, methods=["post"])
    @transaction.atomic
    def cancel(self, request, pk=None):
        """POST /api/reservations/{id}/cancel/ — `status` est en lecture
        seule sur le serializer (source de vérité côté serveur), donc
        l'annulation passe par cette action dédiée plutôt qu'un PATCH brut.
        Libère aussi la propriété (occupee -> disponible) si c'est elle qui
        l'avait occupée."""
        reservation = self.get_object()
        reservation.status = "annulee"
        reservation.save(update_fields=["status"])

        property_obj = reservation.property
        if property_obj.status == "occupee":
            property_obj.status = "disponible"
            property_obj.save(update_fields=["status"])

        return Response(self.get_serializer(reservation).data)
