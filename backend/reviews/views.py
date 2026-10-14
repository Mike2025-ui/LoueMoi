from rest_framework import generics, permissions
from rest_framework.exceptions import PermissionDenied

from notifications.models import Notification
from notifications.services import NotificationService
from properties.models import Property
from reservations.models import Reservation

from .models import Review
from .serializers import ReviewSerializer


class PropertyReviewListCreateView(generics.ListCreateAPIView):
    """GET/POST /api/properties/{property_id}/reviews/"""

    serializer_class = ReviewSerializer
    permission_classes = [permissions.IsAuthenticatedOrReadOnly]

    def get_queryset(self):
        return Review.objects.filter(property_id=self.kwargs["property_id"])

    def perform_create(self, serializer):
        property_obj = Property.objects.get(pk=self.kwargs["property_id"])

        # Règle métier : un avis n'est autorisé que si l'auteur a une
        # réservation "accomplie" sur ce bien précis — un avis "enCours" ou
        # "annulee" ne suffit pas, et un utilisateur n'ayant jamais réservé
        # ce bien ne peut pas en laisser un.
        has_completed_reservation = Reservation.objects.filter(
            property=property_obj, user=self.request.user, status="accomplie"
        ).exists()
        if not has_completed_reservation:
            raise PermissionDenied(
                "Vous devez avoir une réservation accomplie pour ce bien avant de "
                "pouvoir laisser un avis."
            )

        review = serializer.save(user=self.request.user, property=property_obj)

        # Le propriétaire réel du bien — agent ou bailleur, jamais supposé
        # être l'agent (Property.agent est la colonne, mais son occupant
        # peut être l'un ou l'autre rôle).
        NotificationService.notify(
            recipient=property_obj.agent,
            notif_type=Notification.TYPE_NEW_REVIEW,
            title="Nouvel avis",
            body=f"Vous avez reçu un nouvel avis pour « {property_obj.title} ».",
            property=property_obj,
            data={"property_id": str(property_obj.id), "review_id": str(review.id)},
            actor=self.request.user,
        )
