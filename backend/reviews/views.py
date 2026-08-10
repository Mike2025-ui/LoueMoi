from rest_framework import generics, permissions

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
        serializer.save(user=self.request.user, property=property_obj)
