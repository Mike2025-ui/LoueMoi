from rest_framework import generics, permissions
from rest_framework.exceptions import ValidationError

from notifications.models import Notification
from notifications.services import NotificationService
from properties.models import Property

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

        # Règle métier : tout le monde peut donner son avis et attribuer des étoiles
        # à une annonce, à l'exception du propriétaire du bien lui-même.
        if property_obj.agent == self.request.user:
            raise ValidationError("Vous ne pouvez pas laisser d'avis sur votre propre annonce.")

        review = serializer.save(user=self.request.user, property=property_obj)

        # Le propriétaire réel du bien est notifié de l'avis reçu
        NotificationService.notify(
            recipient=property_obj.agent,
            notif_type=Notification.TYPE_NEW_REVIEW,
            title="Nouvel avis",
            body=f"Vous avez reçu un nouvel avis ({review.rating}★) pour « {property_obj.title} ».",
            property=property_obj,
            data={"property_id": str(property_obj.id), "review_id": str(review.id)},
            actor=self.request.user,
        )
