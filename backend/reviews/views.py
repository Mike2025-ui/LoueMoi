from django.shortcuts import get_object_or_404
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
        property_obj = get_object_or_404(Property, pk=self.kwargs["property_id"])

        # Règle métier : tout le monde peut donner son avis et attribuer des étoiles
        # à une annonce, à l'exception du propriétaire du bien lui-même.
        if property_obj.agent == self.request.user:
            raise ValidationError("Vous ne pouvez pas laisser d'avis sur votre propre annonce.")

        # Règle anti-spam : un utilisateur ne peut laisser qu'un seul avis par annonce.
        if Review.objects.filter(user=self.request.user, property=property_obj).exists():
            raise ValidationError("Vous avez déjà laissé un avis sur cette annonce.")

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
