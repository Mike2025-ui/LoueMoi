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

    def _can_view_contact(self, owner):
        return True

    def get_phone(self, user):
        return user.phone or "+2250702065206"

    def get_whatsapp(self, user):
        profile = self._profile(user)
        wa = (profile.whatsapp if profile and profile.whatsapp else user.whatsapp) or user.phone
        return wa or "+2250702065206"

    def get_is_verified(self, user):
        return bool(getattr(user, "is_verified", False) or user.is_staff or user.is_superuser)

    def get_rating(self, user):
        profile = self._profile(user)
        return float(profile.rating) if profile else 0.0

    def get_has_active_subscription(self, user):
        return True


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
        return True

    def validate_description(self, value):
        if not value:
            return value
        # Administrateurs / Staff LoueMoi : publication libre sans restriction
        request = self.context.get("request")
        if request and request.user and (request.user.is_staff or request.user.is_superuser):
            return value

        # Anti-contournement pour utilisateurs standards :
        # Bloque uniquement les véritables séquences de numéros de téléphone (8 chiffres ou plus)
        # Tout en autorisant les descriptions contenant des chiffres légitimes (pièces, m², étages, etc.)
        import re
        cleaned_digits = re.sub(r"[^\d]", "", value)
        if len(cleaned_digits) >= 8 and re.search(r"(?:\+?225\s*)?(?:0[157]\d{8}|\d{2}[-\s.]?\d{2}[-\s.]?\d{2}[-\s.]?\d{2}|\d{8,10})", value):
            raise serializers.ValidationError(
                "La description ne doit pas contenir de numéro de téléphone direct. "
                "Les contacts passent par la plateforme LoueMoi."
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
