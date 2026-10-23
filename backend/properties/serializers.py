from django.contrib.auth import get_user_model
from rest_framework import serializers

from .models import Favorite, Property

User = get_user_model()


class AgentSerializer(serializers.Serializer):
    """Sérialise un User agent au format Agent attendu par Flutter
    (lib/features/properties/models/agent.dart). `is_verified`/`rating`
    viennent de agents.AgentProfile (pas de User) — ce serializer les
    aplatit pour ne rien changer côté contrat JSON Flutter."""

    id = serializers.IntegerField(source="pk")
    first_name = serializers.CharField()
    last_name = serializers.CharField()
    phone = serializers.SerializerMethodField()
    whatsapp = serializers.SerializerMethodField()
    photo = serializers.CharField(allow_null=True)
    role = serializers.CharField()
    is_verified = serializers.SerializerMethodField()
    rating = serializers.SerializerMethodField()
    has_active_subscription = serializers.SerializerMethodField()

    def _profile(self, user):
        return getattr(user, "agent_profile", None)

    def _owner_has_active_sub(self, owner):
        prefetched = getattr(owner, "_prefetched_has_active_sub", None)
        if prefetched is not None:
            return bool(prefetched)
        from django.utils import timezone
        now = timezone.now()
        res = bool(
            hasattr(owner, "subscriptions")
            and owner.subscriptions.filter(status="active", expires_at__gt=now).exists()
        )
        owner._prefetched_has_active_sub = res
        return res

    def _owner_had_any_sub(self, owner):
        prefetched = getattr(owner, "_prefetched_had_any_sub", None)
        if prefetched is not None:
            return bool(prefetched)
        res = bool(
            hasattr(owner, "subscriptions")
            and owner.subscriptions.filter(status__in=["active", "expired"]).exists()
        )
        owner._prefetched_had_any_sub = res
        return res

    def _can_view_contact(self, owner):
        """Protège les numéros personnels (téléphone/WhatsApp) côté serveur :
        visibles uniquement si le propriétaire est abonné, ou si le visiteur
        connecté est le propriétaire lui-même, un admin, ou possède un abonnement actif."""
        if self._owner_has_active_sub(owner):
            return True
        request = self.context.get("request")
        req_user = getattr(request, "user", None) if request else None
        if req_user and getattr(req_user, "is_authenticated", False):
            if req_user.id == owner.id or getattr(req_user, "is_staff", False):
                return True
            cached_req_sub = getattr(request, "_cached_req_user_has_sub", None)
            if cached_req_sub is None:
                from django.utils import timezone
                now = timezone.now()
                cached_req_sub = bool(
                    hasattr(req_user, "subscriptions")
                    and req_user.subscriptions.filter(status="active", expires_at__gt=now).exists()
                )
                try:
                    setattr(request, "_cached_req_user_has_sub", cached_req_sub)
                except Exception:
                    pass
            if cached_req_sub:
                return True
        return False

    def get_phone(self, user):
        if not self._can_view_contact(user):
            return ""
        return user.phone or ""

    def get_whatsapp(self, user):
        if not self._can_view_contact(user):
            return ""
        profile = self._profile(user)
        return (profile.whatsapp if profile and profile.whatsapp else user.whatsapp) or ""

    def get_is_verified(self, user):
        # 1. Tout abonnement actif confère le badge
        if self._owner_has_active_sub(user):
            return True
        # 2. Après expiration d'un abonnement, le badge est révoqué
        if self._owner_had_any_sub(user):
            return False
        # 3. Badge administratif
        if getattr(user, "is_verified", False):
            return True
        profile = self._profile(user)
        if profile and profile.is_verified:
            return True
        return False

    def get_rating(self, user):
        profile = self._profile(user)
        return float(profile.rating) if profile else 0.0

    def get_has_active_subscription(self, user):
        return self._owner_has_active_sub(user)


class PropertySerializer(serializers.ModelSerializer):
    agent = AgentSerializer(read_only=True)
    is_favorite = serializers.SerializerMethodField()
    owner_has_active_subscription = serializers.SerializerMethodField()

    class Meta:
        model = Property
        fields = [
            "id",
            "title",
            "description",
            "type",
            "category",
            "transaction_type",
            "price",
            "deposit",
            "advance",
            "city",
            "commune",
            "district",
            "address",
            "latitude",
            "longitude",
            "status",
            "is_future",
            "is_favorite",
            "images",
            "cover_image",
            "video",
            "features",
            "amenities",
            "agent",
            "views_count",
            "favorites_count",
            "owner_has_active_subscription",
            "published_at",
            "expires_at",
            "created_at",
            "updated_at",
        ]
        # `agent` n'est jamais choisi par le client : perform_create()
        # l'assigne toujours à request.user (voir views.IsAgent). Pas de
        # champ `agent_id` écrivable — empêche un agent de publier une
        # annonce au nom d'un autre agent. views_count/favorites_count sont
        # incrémentés uniquement côté serveur (actions dédiées), jamais
        # écrivables directement par le client. `status` en lecture seule
        # ici : un PATCH générique contournait sinon complètement la
        # validation métier de PropertyViewSet.mark_status (occupee/vendue
        # cohérents avec transaction_type) — un seul chemin API pour
        # changer le statut, jamais deux. Même raisonnement pour `video` :
        # un PATCH générique contournerait la validation (taille/format/
        # durée) et le nettoyage de fichier de PropertyViewSet.upload_video
        # — un seul chemin API pour la modifier.
        read_only_fields = [
            "id",
            "status",
            "views_count",
            "favorites_count",
            "owner_has_active_subscription",
            "video",
            "published_at",
            "expires_at",
            "created_at",
            "updated_at",
        ]

    def to_representation(self, instance):
        if instance.agent_id and getattr(instance, "agent", None) is not None:
            if hasattr(instance, "_owner_has_active_sub"):
                instance.agent._prefetched_has_active_sub = bool(instance._owner_has_active_sub)
            if hasattr(instance, "_owner_had_any_sub"):
                instance.agent._prefetched_had_any_sub = bool(instance._owner_had_any_sub)
        return super().to_representation(instance)

    def get_is_favorite(self, obj):
        if hasattr(obj, "_is_favorited"):
            return bool(obj._is_favorited)
        request = self.context.get("request")
        if request is None or not request.user.is_authenticated:
            return False
        return Favorite.objects.filter(user=request.user, property=obj).exists()

    def get_owner_has_active_subscription(self, obj):
        if hasattr(obj, "_owner_has_active_sub"):
            return bool(obj._owner_has_active_sub)
        if not obj.agent:
            return False
        from django.utils import timezone
        return obj.agent.subscriptions.filter(
            status="active",
            expires_at__gt=timezone.now(),
        ).exists()

    def validate_description(self, value):
        if not value:
            return value
        import re
        # Règle anti-contournement d'abonnement :
        # Empêche l'agent ou le bailleur d'insérer un numéro de téléphone dans la description.
        # La description doit contenir uniquement des caractères alphabétiques (pas de chiffres).
        if re.search(r"\d", value):
            raise serializers.ValidationError(
                "La description ne doit contenir aucun chiffre ni numéro de téléphone. "
                "Utilisez uniquement des caractères alphabétiques."
            )
        return value

    def validate(self, attrs):
        # Les plages (-90/90, -180/180) sont déjà validées via les
        # validators du modèle (propagés automatiquement par DRF). Ici on
        # vérifie seulement la cohérence : une position n'a de sens que si
        # les deux coordonnées sont fournies ensemble.
        latitude = attrs.get("latitude", getattr(self.instance, "latitude", None))
        longitude = attrs.get("longitude", getattr(self.instance, "longitude", None))
        if (latitude is None) != (longitude is None):
            raise serializers.ValidationError(
                {"latitude": ["latitude et longitude doivent être fournies ensemble."]}
            )
        return attrs


class PropertyNearbySerializer(PropertySerializer):
    """Utilisé uniquement par GET /api/properties/nearby/ — ajoute
    `distance_km`, calculée côté SQL (annotation Haversine), jamais
    recalculée côté Flutter."""

    distance_km = serializers.FloatField(read_only=True)

    class Meta(PropertySerializer.Meta):
        fields = PropertySerializer.Meta.fields + ["distance_km"]


class FavoriteSerializer(serializers.ModelSerializer):
    class Meta:
        model = Favorite
        fields = ["id", "user", "property", "created_at"]
        read_only_fields = ["id", "user", "created_at"]
