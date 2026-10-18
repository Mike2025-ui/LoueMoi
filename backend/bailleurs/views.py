from django.contrib.auth import get_user_model
from django.db.models import Avg, Q, Sum
from rest_framework import generics, permissions
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.permissions import HasActiveSubscription, IsBailleur
from messaging.models import Conversation
from properties.models import Favorite, Property
from properties.serializers import PropertySerializer
from reservations.models import Reservation
from reviews.models import Review

from .serializers import BailleurSearchSerializer

User = get_user_model()


class BailleurDashboardView(APIView):
    """GET /api/bailleur/dashboard/ — statistiques réelles du bailleur
    connecté. Jamais calculé/codé en dur côté Flutter : uniquement affiché.
    Même structure de réponse que /api/agent/dashboard/ (voir
    agents.views.AgentDashboardView) — bailleur et agent sont deux rôles
    indépendants mais partagent le même modèle Property (colonne `agent`,
    conservée pour compatibilité), donc les mêmes agrégations s'appliquent."""

    permission_classes = [permissions.IsAuthenticated, IsBailleur]

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
            "messages_count": (
                Conversation.objects.filter(Q(client=user) | Q(agent=user))
                .filter(messages__isnull=False)
                .distinct()
                .count()
            ),
            "reviews_count": reviews.count(),
            "average_rating": round(float(average_rating), 2) if average_rating else 0.0,
        }
        return Response(data)


class BailleurPropertiesView(generics.ListAPIView):
    """GET /api/bailleur/properties/ — uniquement les annonces du bailleur
    connecté (tous statuts, y compris "occupee"). Filtrage côté Django
    uniquement, jamais côté Flutter — un bailleur ne voit jamais les biens
    d'un autre bailleur ni ceux d'un agent."""

    serializer_class = PropertySerializer
    permission_classes = [permissions.IsAuthenticated, IsBailleur]

    def get_queryset(self):
        return (
            Property.objects.filter(agent=self.request.user)
            .exclude(status="disabled")
            .exclude(status="accomplie")
            .select_related("agent", "agent__agent_profile")
        )

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context["request"] = self.request
        return context


class BailleurSearchView(generics.ListAPIView):
    """GET /api/bailleurs/ — annuaire public des bailleurs, symétrique de
    GET /api/agents/ (voir agents.views.AgentSearchView). Décision métier
    (mission de finalisation, "Recherche propriétaire") : un agent peut
    rechercher un bailleur, consulter son profil public et ses annonces
    publiques (déjà servies par GET /api/properties/?agent=<id>, voir
    properties.filters.PropertyFilter), puis éventuellement le contacter —
    aucun transfert de propriété, aucune publication au nom d'autrui : ce
    endpoint ne fait que lister des profils publics, il ne touche jamais à
    Property.agent.

    Reste public (comme AgentSearchView) : rien n'empêche un client ou un
    autre bailleur de l'utiliser aussi.

    Filtres :
      ?search=Kouadio — nom/prénom (icontains)
      ?city=Abidjan   — dérivé des annonces existantes du bailleur
                        (Property.city), même principe que AgentSearchView.
    """

    serializer_class = BailleurSearchSerializer
    permission_classes = [permissions.IsAuthenticated, HasActiveSubscription]

    def get_queryset(self):
        queryset = User.objects.filter(role=User.ROLE_BAILLEUR, is_active=True, is_approved=True)

        search = self.request.query_params.get("search")
        if search:
            queryset = queryset.filter(
                Q(first_name__icontains=search) | Q(last_name__icontains=search)
            )

        city = self.request.query_params.get("city")
        if city:
            queryset = queryset.filter(properties__city__icontains=city).distinct()

        return queryset.order_by("first_name", "last_name")
