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
    phone = serializers.CharField()
    whatsapp = serializers.SerializerMethodField()
    photo = serializers.CharField(allow_null=True)
    is_verified = serializers.SerializerMethodField()
    rating = serializers.SerializerMethodField()

    def _profile(self, user):
        return getattr(user, "agent_profile", None)

    def get_whatsapp(self, user):
        profile = self._profile(user)
        return (profile.whatsapp if profile and profile.whatsapp else user.whatsapp)

    def get_is_verified(self, user):
        profile = self._profile(user)
        return bool(profile and profile.is_verified)

    def get_rating(self, user):
        profile = self._profile(user)
        return float(profile.rating) if profile else 0.0


class PropertySerializer(serializers.ModelSerializer):
    agent = AgentSerializer(read_only=True)
    is_favorite = serializers.SerializerMethodField()

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
            "video",
            "published_at",
            "expires_at",
            "created_at",
            "updated_at",
        ]

    def get_is_favorite(self, obj):
        request = self.context.get("request")
        if request is None or not request.user.is_authenticated:
            return False
        return Favorite.objects.filter(user=request.user, property=obj).exists()

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
