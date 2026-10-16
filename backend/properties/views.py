import math

from django.core.files.storage import default_storage
from django.db.models import ExpressionWrapper, F, FloatField, Q, Value
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
        base = Property.objects.select_related("agent", "agent__agent_profile").exclude(
            status="disabled"
        )
        not_expired = Q(expires_at__isnull=True) | Q(expires_at__gt=timezone.now())
        user = self.request.user
        if user.is_authenticated:
            return base.filter(not_expired | Q(agent=user))
        return base.filter(not_expired)

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
        """Reservation.property est en PROTECT (on garde l'historique des
        réservations même après suppression d'une annonce) : une suppression
        qui violerait cette contrainte doit renvoyer une erreur propre (409),
        jamais un 500 non géré."""
        instance = self.get_object()
        video_field = instance.video
        try:
            instance.delete()
        except ProtectedError:
            return Response(
                {"detail": "Impossible de supprimer une annonce ayant des réservations."},
                status=status.HTTP_409_CONFLICT,
            )
        # Nettoyage du fichier vidéo uniquement après suppression réussie de
        # la ligne — si ProtectedError est levée ci-dessus (réservations
        # actives), l'annonce ET sa vidéo doivent rester intactes.
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
            if request.user != property_obj.agent:
                from notifications.models import Notification
                from notifications.services import NotificationService

                user_display = request.user.get_full_name() or request.user.phone or "Un utilisateur"
                NotificationService.notify(
                    recipient=property_obj.agent,
                    title="Nouveau favori",
                    body=f"{user_display} a ajouté votre annonce \"{property_obj.title}\" à ses favoris.",
                    notif_type=getattr(Notification, "TYPE_NEW_FAVORITE", "new_favorite"),
                    data={"property_id": str(property_obj.pk)},
                    property_obj=property_obj,
                )
        property_obj.favorites_count = property_obj.favorited_by.count()
        property_obj.save(update_fields=["favorites_count"])
        serializer = self.get_serializer(property_obj)
        return Response(serializer.data, status=status.HTTP_200_OK)

    @action(detail=True, methods=["post"])
    def view(self, request, pk=None):
        """POST /api/properties/{id}/view/ — incrémente views_count côté
        serveur uniquement (jamais depuis Flutter directement). L'agent
        propriétaire qui consulte sa propre annonce n'incrémente pas son
        propre compteur (protection basique contre l'auto-gonflage)."""
        property_obj = self.get_object()
        is_owner = request.user.is_authenticated and property_obj.agent_id == request.user.id
        if not is_owner:
            property_obj.views_count += 1
            property_obj.save(update_fields=["views_count"])
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
            allowed = ("disponible", "vendue")
        else:
            allowed = ("disponible", "occupee")

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

        Décision métier retenue : une annonce reste valide
        PROPERTY_VALIDITY_DAYS (30) jours après publication, au-delà elle
        disparaît des résultats publics (voir get_queryset). Reconduire fixe
        une nouvelle période de 30 jours à partir de maintenant
        (publish_for_new_period, la même méthode qu'à la création) — même
        annonce, même id, mêmes photos/réservations/propriétaire, jamais un
        doublon. Réservé au propriétaire réel du bien."""
        property_obj = self.get_object()
        property_obj.publish_for_new_period()
        property_obj.save(update_fields=["published_at", "expires_at", "updated_at"])
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
            is_cover = str(request.data.get("is_cover", "")).lower() in ("1", "true", "yes")
            category = str(request.data.get("category", "")).strip().lower()
            file_name = image_file.name
            if category and not file_name.startswith("cat_"):
                file_name = f"cat_{category}_{file_name}"
            saved_path = default_storage.save(
                f"properties/{property_obj.pk}/{file_name}", image_file
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
            .select_related("agent", "agent__agent_profile")
        )

        # Exclure les annonces expirées
        not_expired = Q(expires_at__isnull=True) | Q(expires_at__gt=timezone.now())
        qs = qs.filter(not_expired)

        if lat_raw and lng_raw:
            try:
                lat = float(lat_raw)
                lng = float(lng_raw)
                qs = qs.annotate(distance_km=_haversine_distance_km(lat, lng))

                if radius_raw and radius_raw not in ("0", "all", "toutes", ""):
                    try:
                        radius_km = float(radius_raw)
                        if radius_km > 0:
                            qs = qs.filter(distance_km__lte=radius_km)
                    except (TypeError, ValueError):
                        pass

                return qs.order_by("distance_km")
            except (TypeError, ValueError):
                pass

        return qs.order_by("-created_at")

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context["request"] = self.request
        return context


class MyPropertiesView(generics.ListAPIView):
    """GET /api/agent/properties/ — uniquement les annonces de l'agent
    connecté (tous statuts, y compris "occupee"). Le filtrage se fait ici,
    côté Django, jamais côté Flutter."""

    serializer_class = PropertySerializer
    permission_classes = [permissions.IsAuthenticated, IsAgent]

    def get_queryset(self):
        return (
            Property.objects.filter(agent=self.request.user)
            .exclude(status="disabled")
            .select_related("agent", "agent__agent_profile")
        )

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context["request"] = self.request
        return context
