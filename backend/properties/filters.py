from django_filters import rest_framework as filters

from .models import Property


class PropertyFilter(filters.FilterSet):
    """Correspond à FilterParams côté Flutter (lib/features/filters/models/filter_params.dart)."""

    commune = filters.CharFilter(field_name="commune", lookup_expr="icontains")
    district = filters.CharFilter(field_name="district", lookup_expr="icontains")
    budget_min = filters.NumberFilter(field_name="price", lookup_expr="gte")
    budget_max = filters.NumberFilter(field_name="price", lookup_expr="lte")
    # ?agent=<id> — annonces publiques d'un propriétaire donné (agent ou
    # bailleur, colonne `agent` conservée pour compatibilité). Utilisé par
    # "Rechercher un propriétaire" côté agent (voir bailleurs.views.
    # BailleurSearchView) : passe par ce filtre plutôt qu'un nouvel
    # endpoint, donc respecte automatiquement les mêmes règles de
    # visibilité publique que le reste de /api/properties/ (annonces
    # expirées/désactivées déjà exclues par PropertyViewSet.get_queryset).
    agent = filters.NumberFilter(field_name="agent_id")

    # Utilisé par l'écran Favoris (favoritesListProvider côté Flutter) :
    # ?favorites_only=true ne renvoie que les biens favoris de l'utilisateur
    # connecté. `self.request` est fourni par DjangoFilterBackend car cette
    # classe hérite de django_filters.rest_framework.FilterSet.
    favorites_only = filters.BooleanFilter(method="filter_favorites_only")

    class Meta:
        model = Property
        fields = ["transaction_type", "type", "category", "status", "is_future"]

    def filter_favorites_only(self, queryset, name, value):
        user = getattr(self.request, "user", None)
        if value and user is not None and user.is_authenticated:
            return queryset.filter(favorited_by__user=user)
        return queryset
