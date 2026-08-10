from django.core.files.storage import default_storage
from django.db.models.deletion import ProtectedError
from rest_framework import generics, permissions, status, viewsets
from rest_framework.decorators import action
from rest_framework.response import Response

from accounts.permissions import IsAgent

from .filters import PropertyFilter
from .models import Favorite, Property
from .permissions import IsPropertyOwnerOrReadOnly
from .serializers import PropertySerializer


class PropertyViewSet(viewsets.ModelViewSet):
    """/api/properties/ — liste publique (toutes les annonces, tous agents
    confondus) + CRUD réservé à l'agent propriétaire pour les mutations.

    - GET (list/retrieve) : ouvert à tous (lecture publique).
    - POST (create) : agents authentifiés uniquement, toujours assigné à
      request.user (jamais un agent arbitraire choisi par le client).
      Aucune étape d'approbation : le statut par défaut du modèle
      ("disponible") rend l'annonce publique immédiatement.
    - PUT/PATCH/DELETE/upload_image : agent propriétaire uniquement.

    Les annonces `status=disabled` (intervention admin, Django Admin
    uniquement) sont exclues de cette API — publique comme "mes annonces".
    """

    queryset = (
        Property.objects.select_related("agent", "agent__agent_profile")
        .exclude(status="disabled")
    )
    serializer_class = PropertySerializer
    filterset_class = PropertyFilter

    def get_permissions(self):
        if self.action == "create":
            return [permissions.IsAuthenticated(), IsAgent()]
        if self.action in ("update", "partial_update", "destroy", "upload_image"):
            return [permissions.IsAuthenticated(), IsAgent(), IsPropertyOwnerOrReadOnly()]
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
        serializer.save(agent=self.request.user)

    def destroy(self, request, *args, **kwargs):
        """Reservation.property est en PROTECT (on garde l'historique des
        réservations même après suppression d'une annonce) : une suppression
        qui violerait cette contrainte doit renvoyer une erreur propre (409),
        jamais un 500 non géré."""
        instance = self.get_object()
        try:
            instance.delete()
        except ProtectedError:
            return Response(
                {"detail": "Impossible de supprimer une annonce ayant des réservations."},
                status=status.HTTP_409_CONFLICT,
            )
        return Response(status=status.HTTP_204_NO_CONTENT)

    @action(detail=True, methods=["post"])
    def favorite(self, request, pk=None):
        property_obj = self.get_object()
        favorite, created = Favorite.objects.get_or_create(user=request.user, property=property_obj)
        if not created:
            favorite.delete()
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
            saved_path = default_storage.save(
                f"properties/{property_obj.pk}/{image_file.name}", image_file
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
