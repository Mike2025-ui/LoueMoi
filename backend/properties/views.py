import math
import os
import re
import uuid

from PIL import Image

from django.core.files.storage import default_storage
from django.db.models import (
    BooleanField,
    Exists,
    ExpressionWrapper,
    F,
    FloatField,
    OuterRef,
    Q,
    Value,
)
from django.db.models.deletion import ProtectedError
from django.db.models.functions import ASin, Cast, Cos, Power, Radians, Sin, Sqrt
from django.utils import timezone
from rest_framework import generics, permissions, status, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import ValidationError
from rest_framework.response import Response

from accounts.permissions import CanOwnProperties, IsAgent

from .filters import PropertyFilter
from .models import Favorite, Property
from .permissions import IsPropertyOwnerOrReadOnly
from .serializers import PropertyNearbySerializer, PropertySerializer
from .video_utils import validate_video_file

EARTH_RADIUS_KM = 6371.0


def _haversine_distance_km(origin_latitude, origin_longitude):
    """Annotation ORM calculant la distance (km) entre chaque ligne et un
    point d'origine, formule de Haversine. Utilise uniquement des fonctions
    SQL standard (RADIANS/SIN/COS/ASIN/SQRT/POWER, via
    django.db.models.functions) — portable SQLite ET PostgreSQL, sans
    PostGIS. Le point d'origine est injecté comme constante Python (déjà
    validé par l'appelant), jamais concaténé en SQL brut."""
    origin_lat_rad = math.radians(origin_latitude)
    origin_lng_rad = math.radians(origin_longitude)
    origin_cos_lat = math.cos(origin_lat_rad)

    lat_rad = Radians(Cast(F("latitude"), FloatField()), output_field=FloatField())
    lng_rad = Radians(Cast(F("longitude"), FloatField()), output_field=FloatField())

    dlat = ExpressionWrapper(lat_rad - Value(origin_lat_rad), output_field=FloatField())
    dlng = ExpressionWrapper(lng_rad - Value(origin_lng_rad), output_field=FloatField())

    sin_dlat_half = Sin(ExpressionWrapper(dlat / 2.0, output_field=FloatField()))
    sin_dlng_half = Sin(ExpressionWrapper(dlng / 2.0, output_field=FloatField()))

    a = ExpressionWrapper(
        Power(sin_dlat_half, 2)
        + Value(origin_cos_lat) * Cos(lat_rad) * Power(sin_dlng_half, 2),
        output_field=FloatField(),
    )
    c = ExpressionWrapper(ASin(Sqrt(a)) * 2.0, output_field=FloatField())
    return ExpressionWrapper(c * EARTH_RADIUS_KM, output_field=FloatField())


def annotate_property_queryset(queryset, user=None):
    """Pré-calcule en 1 seule requête SQL (Exists/OuterRef) les booléens
    d'abonnement propriétaire et de favori utilisateur pour éliminer les
    ~140 requêtes N+1 par page de PropertySerializer & AgentSerializer."""
    from payments.models import Subscription

    now = timezone.now()
    active_sub_sq = Subscription.objects.filter(
        user_id=OuterRef("agent_id"),
        status="active",
        expires_at__gt=now,
    )
    any_sub_sq = Subscription.objects.filter(
        user_id=OuterRef("agent_id"),
        status__in=["active", "expired"],
    )
    annotations = {
        "_owner_has_active_sub": Exists(active_sub_sq),
        "_owner_had_any_sub": Exists(any_sub_sq),
    }
    if user is not None and getattr(user, "is_authenticated", False):
        fav_sq = Favorite.objects.filter(
            user_id=user.id,
            property_id=OuterRef("pk"),
        )
        annotations["_is_favorited"] = Exists(fav_sq)
    else:
        annotations["_is_favorited"] = Value(False, output_field=BooleanField())

    return queryset.annotate(**annotations)


class PropertyViewSet(viewsets.ModelViewSet):
    """/api/properties/ — liste publique (toutes les annonces, tous
    agents/bailleurs confondus) + CRUD réservé au propriétaire pour les
    mutations.

    - GET (list/retrieve) : ouvert à tous (lecture publique).
    - POST (create) : agents ET bailleurs authentifiés (rôles indépendants,
      voir CanOwnProperties), toujours assigné à request.user (jamais un
      agent/bailleur arbitraire choisi par le client). Aucune étape
      d'approbation : le statut par défaut du modèle ("disponible") rend
      l'annonce publique immédiatement.
    - PUT/PATCH/DELETE/upload_image/upload_video : propriétaire uniquement.

    Les annonces `status=disabled` (intervention admin, Django Admin
    uniquement) sont exclues de cette API — publique comme "mes annonces".

    Une annonce expirée (Property.expires_at dépassé — voir "Reconduire",
    PROPERTY_VALIDITY_DAYS) n'apparaît plus dans les résultats publics,
    exactement comme une annonce désactivée : les autres utilisateurs ne la
    voient plus ni dans la liste ni en détail. Le propriétaire garde accès
    à ses propres annonces même expirées (via cette même API, pas seulement
    /api/agent/properties/) pour pouvoir les consulter et les reconduire.
    expires_at NULL (annonces publiées avant l'introduction de ce système)
    n'expire jamais — jamais de disparition rétroactive d'une annonce déjà
    publiée.
    """

    serializer_class = PropertySerializer
    filterset_class = PropertyFilter

    def get_queryset(self):
        base = (
            Property.objects.select_related("agent", "agent__agent_profile")
            .exclude(status="disabled")
            .exclude(status="accomplie")
        )
        not_expired = Q(expires_at__isnull=True) | Q(expires_at__gt=timezone.now())
        user = self.request.user
        if user.is_authenticated:
            qs = base.filter(not_expired | Q(agent=user))
        else:
            qs = base.filter(not_expired)
        return annotate_property_queryset(qs, user)

    def get_permissions(self):
        if self.action == "create":
            return [permissions.IsAuthenticated(), CanOwnProperties()]
        if self.action in (
            "update",
            "partial_update",
            "destroy",
            "upload_image",
            "upload_video",
            "mark_status",
            "renew",
        ):
            return [permissions.IsAuthenticated(), CanOwnProperties(), IsPropertyOwnerOrReadOnly()]
        if self.action == "favorite":
            return [permissions.IsAuthenticated()]
        if self.action == "view":
            return [permissions.AllowAny()]
        return [permissions.IsAuthenticatedOrReadOnly()]

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context["request"] = self.request
        return context

    def perform_create(self, serializer):
        property_obj = serializer.save(agent=self.request.user)
        property_obj.publish_for_new_period()
        property_obj.save(update_fields=["published_at", "expires_at"])

    def destroy(self, request, *args, **kwargs):
        """Règle métier stricte :
        - Si une réservation est en cours (status='enCours'), l'annonce ne peut pas être supprimée.
        - Si les réservations associées sont accomplies ou annulées, l'annonce peut être supprimée."""
        instance = self.get_object()
        if instance.reservations.filter(status="enCours").exists():
            return Response(
                {
                    "detail": "Impossible de supprimer cette annonce : une réservation est actuellement en cours. "
                    "Vous devez d'abord la finaliser (accomplie) ou l'annuler."
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        video_field = instance.video
        # Nettoyage des réservations terminées (accomplies ou annulées) pour lever la contrainte PROTECT
        instance.reservations.filter(status__in=["accomplie", "annulee"]).delete()
        instance.delete()

        if video_field:
            video_field.delete(save=False)
        return Response(status=status.HTTP_204_NO_CONTENT)

    @action(detail=True, methods=["post"])
    def favorite(self, request, pk=None):
        property_obj = self.get_object()
        favorite, created = Favorite.objects.get_or_create(user=request.user, property=property_obj)
        if not created:
            favorite.delete()
        else:
            # Notifier uniquement le propriétaire (agent/bailleur) de l'annonce, et rien d'autre
            if property_obj.agent and request.user != property_obj.agent:
                try:
                    from notifications.models import Notification
                    from notifications.services import NotificationService

                    full_name = f"{request.user.first_name} {request.user.last_name}".strip()
                    user_display = full_name or request.user.phone or "Un utilisateur"
                    NotificationService.notify(
                        recipient=property_obj.agent,
                        title="Nouveau favori",
                        body=f"{user_display} a ajouté votre annonce \"{property_obj.title}\" à ses favoris.",
                        notif_type=getattr(Notification, "TYPE_NEW_FAVORITE", "new_favorite"),
                        data={"property_id": str(property_obj.pk)},
                        property=property_obj,
                        actor=request.user,
                    )
                except Exception:
                    pass
        property_obj.favorites_count = property_obj.favorited_by.count()
        property_obj.save(update_fields=["favorites_count"])
        serializer = self.get_serializer(property_obj)
        return Response(serializer.data, status=status.HTTP_200_OK)

    @action(detail=True, methods=["post"])
    def view(self, request, pk=None):
        """POST /api/properties/{id}/view/ — incrémente views_count côté
        serveur uniquement (jamais depuis Flutter directement) de manière
        atomique via F('views_count') + 1. L'agent propriétaire qui consulte
        sa propre annonce n'incrémente pas son propre compteur."""
        property_obj = self.get_object()
        is_owner = request.user.is_authenticated and property_obj.agent_id == request.user.id
        if not is_owner:
            Property.objects.filter(pk=property_obj.pk).update(
                views_count=F("views_count") + 1
            )
            property_obj.refresh_from_db(fields=["views_count"])
        serializer = self.get_serializer(property_obj)
        return Response(serializer.data, status=status.HTTP_200_OK)

    @action(detail=True, methods=["post"], url_path="status")
    def mark_status(self, request, pk=None):
        """POST /api/properties/{id}/status/ — {"status": "disponible"|"occupee"|"vendue"}

        Une réservation ne rend plus une annonce "occupee" automatiquement
        (voir ReservationViewSet.perform_create) : c'est désormais au
        propriétaire réel du bien — bailleur propriétaire ou agent
        propriétaire de l'annonce, jamais un autre agent, jamais un client
        (IsPropertyOwnerOrReadOnly, déjà utilisé pour update/destroy) — de
        décider explicitement quand son bien devient occupé/vendu ou
        redevient disponible. "disabled" reste réservé à l'administration
        Django, jamais accessible ici.

        "occupee" (bien loué) et "vendue" (transaction de vente terminée)
        sont deux statuts distincts, jamais interchangeables : "occupee"
        n'a de sens que pour une annonce en location, "vendue" que pour une
        annonce en vente — décision métier explicite, pas une simple
        validation de forme."""
        property_obj = self.get_object()
        new_status = request.data.get("status")

        if property_obj.transaction_type == "vente":
            allowed = ("disponible", "vendue", "accomplie", "annulee")
        else:
            allowed = ("disponible", "occupee", "accomplie", "annulee")

        if new_status not in allowed:
            return Response(
                {"status": [f"Doit être {' ou '.join(repr(s) for s in allowed)}."]},
                status=status.HTTP_400_BAD_REQUEST,
            )
        property_obj.status = new_status
        property_obj.save(update_fields=["status"])
        return Response(self.get_serializer(property_obj).data, status=status.HTTP_200_OK)

    @action(detail=True, methods=["post"])
    def renew(self, request, pk=None):
        """POST /api/properties/{id}/renew/ — "Reconduire un bien".
        Seules les annonces annulées peuvent être reconduites.
        Une annonce accomplie ne peut plus jamais être reconduite."""
        property_obj = self.get_object()
        if property_obj.status == "accomplie":
            return Response(
                {"detail": "Une annonce accomplie ne peut pas être reconduite."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if property_obj.status != "annulee" and not property_obj.is_expired:
            return Response(
                {"detail": "Seules les annonces annulées ou expirées peuvent être reconduites."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        property_obj.status = "disponible"
        property_obj.publish_for_new_period()
        property_obj.save(update_fields=["status", "published_at", "expires_at", "updated_at"])
        return Response(self.get_serializer(property_obj).data, status=status.HTTP_200_OK)

    @action(detail=True, methods=["post", "delete"], url_path="upload-image")
    def upload_image(self, request, pk=None):
        """POST (multipart, champ `image` + `is_cover` optionnel) ajoute une
        photo ; DELETE (`{"url": "..."}`) en retire une. `images`/
        `cover_image` restent aussi modifiables via PATCH classique (pour la
        réorganisation : renvoyer le tableau `images` réordonné)."""
        property_obj = self.get_object()

        if request.method == "POST":
            image_file = request.FILES.get("image")
            if not image_file:
                return Response(
                    {"image": ["Aucun fichier reçu."]}, status=status.HTTP_400_BAD_REQUEST
                )

            # Sécurité : taille maximale 10 Mo par photo
            max_size_bytes = 10 * 1024 * 1024
            if image_file.size > max_size_bytes:
                return Response(
                    {"image": ["La photo dépasse la taille maximale autorisée (10 Mo)."]},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            # Sécurité : validation de l'extension
            ext = os.path.splitext(image_file.name or "")[1].lower()
            allowed_extensions = {".jpg", ".jpeg", ".png", ".webp"}
            if ext not in allowed_extensions:
                return Response(
                    {"image": ["Format d'image non autorisé (JPG, PNG, WebP uniquement)."]},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            # Sécurité : vérification d'intégrité de l'image avec Pillow (anti-script / polyglot)
            try:
                img = Image.open(image_file)
                img.verify()
                image_file.seek(0)
            except Exception:
                return Response(
                    {"image": ["Fichier image corrompu ou invalide."]},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            is_cover = str(request.data.get("is_cover", "")).lower() in ("1", "true", "yes")
            category = str(request.data.get("category", "")).strip().lower()
            # Nettoyage de la catégorie contre les caractères dangereux et path traversal
            clean_category = re.sub(r"[^a-zA-Z0-9_-]", "", category)[:30]
            prefix = f"cat_{clean_category}_" if clean_category else ""
            # Nom de fichier aléatoire sécurisé (UUID) pour prévenir collisions et injections
            safe_file_name = f"{prefix}{uuid.uuid4().hex[:12]}{ext}"

            saved_path = default_storage.save(
                f"properties/{property_obj.pk}/{safe_file_name}", image_file
            )
            url = request.build_absolute_uri(default_storage.url(saved_path))

            images = list(property_obj.images or [])
            images.append(url)
            property_obj.images = images
            if is_cover or not property_obj.cover_image:
                property_obj.cover_image = url
            property_obj.save(update_fields=["images", "cover_image"])
            return Response(self.get_serializer(property_obj).data, status=status.HTTP_201_CREATED)

        # DELETE
        url_to_remove = request.data.get("url")
        if not url_to_remove:
            return Response({"url": ["Requis."]}, status=status.HTTP_400_BAD_REQUEST)
        images = [img for img in (property_obj.images or []) if img != url_to_remove]
        property_obj.images = images
        if property_obj.cover_image == url_to_remove:
            property_obj.cover_image = images[0] if images else ""
        property_obj.save(update_fields=["images", "cover_image"])
        return Response(self.get_serializer(property_obj).data, status=status.HTTP_200_OK)

    @action(detail=True, methods=["post", "delete"], url_path="video")
    def upload_video(self, request, pk=None):
        """POST (multipart, champ `video`) ajoute OU remplace LA vidéo de
        l'annonce — un maximum d'une vidéo par annonce, tout nouvel envoi
        remplace l'ancienne (dont le fichier est supprimé du stockage) ;
        DELETE la retire. Réservé au propriétaire réel (voir get_permissions,
        même permission qu'upload_image). Vidéo facultative : une annonce
        sans vidéo reste parfaitement valide, un changement de statut
        (occupee/vendue) ne la supprime jamais.

        Fonctionnalité DISTINCTE de la vidéo de messagerie (Message.attachment,
        backend/messaging) : modèle, permissions et endpoint différents,
        jamais mélangés."""
        property_obj = self.get_object()

        if request.method == "POST":
            video_file = request.FILES.get("video")
            if not video_file:
                return Response(
                    {"video": ["Aucun fichier reçu."]}, status=status.HTTP_400_BAD_REQUEST
                )

            errors = validate_video_file(
                video_file,
                max_size_bytes=Property.MAX_VIDEO_SIZE_BYTES,
                max_duration_seconds=Property.MAX_VIDEO_DURATION_SECONDS,
                allowed_extensions=Property.ALLOWED_VIDEO_EXTENSIONS,
                allowed_content_types=Property.ALLOWED_VIDEO_CONTENT_TYPES,
            )
            if errors:
                return Response({"video": errors}, status=status.HTTP_400_BAD_REQUEST)

            if property_obj.video:
                property_obj.video.delete(save=False)
            property_obj.video = video_file
            property_obj.save(update_fields=["video"])
            return Response(self.get_serializer(property_obj).data, status=status.HTTP_201_CREATED)

        # DELETE
        if property_obj.video:
            property_obj.video.delete(save=False)
            property_obj.video = None
            property_obj.save(update_fields=["video"])
        return Response(self.get_serializer(property_obj).data, status=status.HTTP_200_OK)


class PropertyNearbyView(generics.ListAPIView):
    """GET /api/properties/nearby/?latitude=&longitude=&radius=

    Recherche géographique publique — mêmes annonces que /api/properties/
    (tous les agents confondus, jamais de données privées), simplement
    filtrées par distance. Le calcul est fait côté SQL (Haversine), jamais
    en récupérant toutes les propriétés pour calculer les distances côté
    Flutter. Les propriétés sans coordonnées sont naturellement exclues."""

    serializer_class = PropertyNearbySerializer
    permission_classes = [permissions.AllowAny]

    def get_queryset(self):
        lat_raw = self.request.query_params.get("latitude")
        lng_raw = self.request.query_params.get("longitude")
        radius_raw = self.request.query_params.get("radius")

        qs = (
            Property.objects.filter(latitude__isnull=False, longitude__isnull=False)
            .exclude(status="disabled")
            .exclude(status="accomplie")
            .exclude(status="annulee")
            .select_related("agent", "agent__agent_profile")
        )

        not_expired = Q(expires_at__isnull=True) | Q(expires_at__gt=timezone.now())
        qs = annotate_property_queryset(qs.filter(not_expired), self.request.user)

        # Si ni latitude ni longitude ne sont passées : afficher toutes les annonces géolocalisées
        if lat_raw is None and lng_raw is None:
            return qs.order_by("-created_at")

        if lat_raw is None or lng_raw is None:
            raise ValidationError({"detail": "latitude et longitude doivent être fournis ensemble."})

        try:
            lat = float(lat_raw)
            lng = float(lng_raw)
        except (TypeError, ValueError):
            raise ValidationError({"detail": "latitude et longitude doivent être des nombres décimaux."})

        if not (-90.0 <= lat <= 90.0):
            raise ValidationError({"latitude": ["Latitude hors intervalle [-90, 90]."]})
        if not (-180.0 <= lng <= 180.0):
            raise ValidationError({"longitude": ["Longitude hors intervalle [-180, 180]."]})

        radius_km = None
        if radius_raw is not None and radius_raw != "":
            if radius_raw in ("0", "all", "toutes"):
                pass
            else:
                try:
                    radius_km = float(radius_raw)
                except (TypeError, ValueError):
                    raise ValidationError({"radius": ["Rayon invalide."]})
                if radius_km <= 0:
                    raise ValidationError({"radius": ["Le rayon doit être strictement positif."]})
                # Pré-filtre Bounding Box indexé (prop_coords_idx) avant Haversine
                delta_lat = (radius_km * 1.05) / 111.0
                cos_lat = max(math.cos(math.radians(lat)), 0.01)
                delta_lng = (radius_km * 1.05) / (111.0 * cos_lat)
                qs = qs.filter(
                    latitude__gte=lat - delta_lat,
                    latitude__lte=lat + delta_lat,
                    longitude__gte=lng - delta_lng,
                    longitude__lte=lng + delta_lng,
                )

        qs = qs.annotate(distance_km=_haversine_distance_km(lat, lng))
        if radius_km is not None:
            qs = qs.filter(distance_km__lte=radius_km)

        return qs.order_by("distance_km")

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context["request"] = self.request
        return context


class MyPropertiesView(generics.ListAPIView):
    """GET /api/agent/properties/ — uniquement les annonces de l'agent
    connecté (tous statuts, y compris "occupee", "accomplie", "annulee").
    Le filtrage se fait ici, côté Django, jamais côté Flutter."""

    serializer_class = PropertySerializer
    permission_classes = [permissions.IsAuthenticated, IsAgent]

    def get_queryset(self):
        qs = (
            Property.objects.filter(agent=self.request.user)
            .exclude(status="disabled")
            .select_related("agent", "agent__agent_profile")
        )
        return annotate_property_queryset(qs, self.request.user)

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context["request"] = self.request
        return context
