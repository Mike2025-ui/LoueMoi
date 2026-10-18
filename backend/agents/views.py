from django.contrib.auth import get_user_model
from django.db.models import Avg, Q, Sum
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from accounts.permissions import IsAgent
from messaging.models import Conversation
from properties.models import Favorite, Property
from reservations.models import Reservation
from reviews.models import Review

from .models import AgentProfile
from .serializers import AgentProfileSerializer, AgentSearchSerializer

User = get_user_model()


class AgentProfileMeView(generics.RetrieveUpdateAPIView):
    """GET/PATCH /api/agent/profile/ — agence, whatsapp, description de
    l'agent connecté (voir "Modification du profil" du cahier des charges).
    `is_verified`/`rating` restent en lecture seule (AgentProfileSerializer) :
    un agent ne peut jamais se vérifier ou se noter lui-même."""

    serializer_class = AgentProfileSerializer
    permission_classes = [permissions.IsAuthenticated, IsAgent]

    def get_object(self):
        profile, _created = AgentProfile.objects.get_or_create(user=self.request.user)
        return profile


class AgentCertificationRequestView(APIView):
    """POST /api/agent/certification/request/ — l'agent connecté demande sa
    certification. Décision métier (mission de finalisation) :

        Agent → demande → EN_ATTENTE → Django Admin → approuvée/refusée

    Un agent ne peut jamais s'auto-certifier : cette vue ne fait QUE passer
    le statut à "en_attente", jamais à "approuvée" — seule l'administration
    (AgentProfileAdmin.approve_certification) peut faire cette transition.
    Refuse une nouvelle demande si une autre est déjà en attente ou déjà
    approuvée (pas de spam de demandes, pas de re-demande inutile)."""

    permission_classes = [permissions.IsAuthenticated, IsAgent]

    def post(self, request):
        profile, _created = AgentProfile.objects.get_or_create(user=request.user)

        if profile.certification_status == AgentProfile.CERTIFICATION_APPROVED:
            return Response(
                {"detail": "Ce compte est déjà certifié."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if profile.certification_status == AgentProfile.CERTIFICATION_PENDING:
            return Response(
                {"detail": "Une demande de certification est déjà en attente."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        profile.certification_status = AgentProfile.CERTIFICATION_PENDING
        profile.save(update_fields=["certification_status"])
        return Response(AgentProfileSerializer(profile).data, status=status.HTTP_200_OK)


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


class AgentSearchView(generics.ListAPIView):
    """GET /api/agents/ — annuaire public des agents (accessible à tout
    utilisateur, y compris anonyme). Utilisé par la rubrique "Trouver un
    agent" côté bailleur, mais reste public : rien n'empêche un client de
    l'utiliser aussi plus tard.

    Filtres :
      ?search=Kouassi  — nom/prénom/nom d'agence (icontains)
      ?city=Abidjan     — dérivé des annonces existantes de l'agent
                          (Property.city), aucun champ "zone" dédié
                          n'existe aujourd'hui — pas de nouvelle donnée
                          inventée pour ce filtre optionnel.
    """

    serializer_class = AgentSearchSerializer
    permission_classes = [permissions.AllowAny]

    def get_queryset(self):
        queryset = User.objects.filter(role=User.ROLE_AGENT).select_related("agent_profile")

        search = self.request.query_params.get("search")
        if search:
            queryset = queryset.filter(
                Q(first_name__icontains=search)
                | Q(last_name__icontains=search)
                | Q(agent_profile__agency_name__icontains=search)
            )

        city = self.request.query_params.get("city")
        if city:
            queryset = queryset.filter(properties__city__icontains=city).distinct()

        return queryset.order_by("first_name", "last_name")
