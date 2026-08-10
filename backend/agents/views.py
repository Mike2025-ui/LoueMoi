from django.contrib.auth import get_user_model
from django.db.models import Avg, Sum
from rest_framework import permissions
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.permissions import IsAgent
from messaging.models import Conversation
from properties.models import Favorite, Property
from reservations.models import Reservation
from reviews.models import Review

User = get_user_model()


class AgentDashboardView(APIView):
    """GET /api/agent/dashboard/ — statistiques réelles de l'agent connecté.
    Jamais calculé/codé en dur côté Flutter : uniquement affiché."""

    permission_classes = [permissions.IsAuthenticated, IsAgent]

    def get(self, request):
        user = request.user
        properties = Property.objects.filter(agent=user).exclude(status="disabled")
        reviews = Review.objects.filter(property__agent=user)
        average_rating = reviews.aggregate(avg=Avg("rating"))["avg"]

        data = {
            "properties_count": properties.count(),
            "available_count": properties.filter(status="disponible").count(),
            "occupied_count": properties.filter(status="occupee").count(),
            "reservations_count": Reservation.objects.filter(property__agent=user).count(),
            "favorites_received": Favorite.objects.filter(property__agent=user).count(),
            "views_count": properties.aggregate(total=Sum("views_count"))["total"] or 0,
            "messages_count": Conversation.objects.filter(agent=user).count(),
            "reviews_count": reviews.count(),
            "average_rating": round(float(average_rating), 2) if average_rating else 0.0,
        }
        return Response(data)
