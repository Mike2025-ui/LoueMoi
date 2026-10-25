from django.db.models import Count, Exists, OuterRef, Q
from django.http import FileResponse, Http404
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import generics, permissions, serializers, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import PermissionDenied
from rest_framework.response import Response
from rest_framework.views import APIView

from notifications.models import Notification
from notifications.services import NotificationService

from .models import Conversation, Message
from .serializers import ConversationSerializer, MessageSerializer


def user_can_access_conversation(user, conversation):
    """Détermine si l'utilisateur est autorisé à consulter/lire les messages d'une conversation.

    Règles métier LoueMoi :
    - Staff / Admin : toujours autorisé.
    - Échanges Pro à Pro (Bailleur <-> Agent, Agent <-> Agent, Bailleur <-> Bailleur) :
      Verrouillé tant qu'aucun des deux n'a d'abonnement actif.
    - Échanges Client <-> Bailleur/Agent :
      Le client peut contacter et échanger avec le bailleur/agent par messagerie interne.
    """
    if not user or not getattr(user, "is_authenticated", False):
        return False
    if getattr(user, "is_staff", False):
        return True

    now = timezone.now()
    other_party = conversation.agent if user == conversation.client else conversation.client

    user_sub = hasattr(user, "subscriptions") and user.subscriptions.filter(status="active", expires_at__gt=now).exists()
    other_sub = other_party and hasattr(other_party, "subscriptions") and other_party.subscriptions.filter(status="active", expires_at__gt=now).exists()

    user_role = getattr(user, "role", "")

    # Règle Pro (Agent ou Bailleur) :
    # Un agent ou bailleur DOIT impérativement avoir son propre abonnement Pro actif pour déverrouiller toute conversation !
    if user_role in ("agent", "bailleur"):
        return bool(user_sub)

    # Règle Client :
    # Un client DOIT également avoir son propre abonnement Client actif pour déverrouiller toute conversation !
    if user_role == "client":
        return bool(user_sub)

    return False


class ConversationViewSet(viewsets.ModelViewSet):
    """/api/conversations/ — conversations de l'utilisateur connecté,
    côté client/bailleur (initiateur) ou côté agent."""

    serializer_class = ConversationSerializer
    permission_classes = [permissions.IsAuthenticated]
    http_method_names = ["get", "post", "delete", "head", "options"]

    def get_queryset(self):
        user = self.request.user
        now = timezone.now()
        # Dès que l'utilisateur relève ses conversations, ses messages entrants sont marqués comme délivrés sur son appareil (✓✓ gris)
        Message.objects.filter(
            receiver=user,
            is_delivered=False,
        ).update(is_delivered=True, delivered_at=now)

        has_messages = Exists(Message.objects.filter(conversation_id=OuterRef("pk")))
        # Ne renvoie que les conversations qui contiennent au moins un message réel
        # pour éviter d'afficher des conversations fantômes non démarrées
        return (
            Conversation.objects.filter(Q(client=user) | Q(agent=user))
            .annotate(_has_messages=has_messages)
            .filter(_has_messages=True)
            .select_related("client", "agent", "property")
            .annotate(
                _unread_count=Count(
                    "messages",
                    filter=Q(messages__is_read=False) & ~Q(messages__sender=user),
                )
            )
            .order_by("-created_at", "-id")
        )

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context["request"] = self.request
        return context

    def perform_create(self, serializer):
        agent = serializer.validated_data["agent"]
        user = self.request.user
        if user == agent:
            raise serializers.ValidationError("Vous ne pouvez pas démarrer une conversation avec vous-même.")

        property_obj = serializer.validated_data.get("property")

        # Règle stricte anti-doublon : recherche toute conversation existante
        # entre ces deux utilisateurs (dans un sens ou dans l'autre).
        # Un utilisateur et un agent n'ont JAMAIS plusieurs fils séparés :
        # l'envoi d'une demande de visite ou d'un message réutilise toujours
        # la conversation existante.
        conversation = Conversation.objects.filter(
            Q(client=user, agent=agent) | Q(client=agent, agent=user)
        ).first()

        if conversation:
            # Réutilise le fil existant. Si l'utilisateur contacte à propos
            # d'une propriété spécifique, on actualise la référence de propriété
            # pour que le contexte de discussion soit à jour.
            if property_obj and conversation.property_id != property_obj.id:
                conversation.property = property_obj
                conversation.save(update_fields=["property"])
            serializer.instance = conversation
            return

        conversation = Conversation.objects.create(
            client=user,
            agent=agent,
            property=property_obj,
        )
        serializer.instance = conversation

    def perform_destroy(self, instance):
        user = self.request.user
        if user not in (instance.client, instance.agent):
            raise PermissionDenied("Vous ne faites pas partie de cette conversation.")
        instance.delete()

    def retrieve(self, request, *args, **kwargs):
        conversation = self.get_object()
        if not user_can_access_conversation(request.user, conversation):
            raise PermissionDenied("Un abonnement actif est requis pour consulter cette conversation.")
        serializer = self.get_serializer(conversation)
        return Response(serializer.data)

    @action(detail=True, methods=["post"], url_path="mark-read")
    def mark_read(self, request, pk=None):
        """POST /api/conversations/{id}/mark-read/ — marque comme lus tous
        les messages de la conversation reçus par l'utilisateur connecté.
        Appelé à l'ouverture de ConversationScreen côté Flutter : sans ça,
        `unread_count` (et donc le badge de l'onglet Messages) ne redescend
        jamais, même après lecture."""
        conversation = self.get_object()
        if not user_can_access_conversation(request.user, conversation):
            raise PermissionDenied("Un abonnement actif est requis pour consulter cette conversation.")
        now = timezone.now()
        unread_messages = conversation.messages.filter(is_read=False).exclude(sender=request.user)
        unread_messages.filter(delivered_at__isnull=True).update(is_delivered=True, delivered_at=now)
        unread_messages.update(
            is_read=True,
            is_delivered=True,
            read_at=now,
        )
        Notification.objects.filter(
            conversation=conversation,
            recipient=request.user,
            type=Notification.TYPE_NEW_MESSAGE,
        ).update(is_read=True)
        conversation._unread_count = 0
        return Response(self.get_serializer(conversation).data)


class MessageListCreateView(generics.ListCreateAPIView):
    """GET /api/messages/?conversation=<id>  —  POST /api/messages/
    (JSON pour le texte, multipart pour une pièce jointe — les deux formats
    sont acceptés nativement par DRF, aucune configuration supplémentaire)."""

    serializer_class = MessageSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        conversation_id = self.request.query_params.get("conversation")
        if conversation_id:
            conversation = get_object_or_404(
                Conversation.objects.select_related("client", "agent"),
                pk=conversation_id,
            )
            if self.request.user not in (conversation.client, conversation.agent):
                raise PermissionDenied("Vous ne faites pas partie de cette conversation.")
            if not user_can_access_conversation(self.request.user, conversation):
                raise PermissionDenied("Un abonnement actif est requis pour consulter les messages de cette conversation.")

            # Marquer automatiquement comme délivrés (2 traits gris) les messages reçus
            Message.objects.filter(
                conversation_id=conversation_id,
                receiver=self.request.user,
                is_delivered=False,
            ).update(is_delivered=True, delivered_at=timezone.now())
            return Message.objects.filter(conversation_id=conversation_id).distinct()

        # Filtrer strictement les conversations autorisées par la politique d'abonnement
        accessible_conv_ids = [
            c.id
            for c in Conversation.objects.filter(
                Q(client=self.request.user) | Q(agent=self.request.user)
            ).select_related("client", "agent")
            if user_can_access_conversation(self.request.user, c)
        ]
        return Message.objects.filter(conversation_id__in=accessible_conv_ids).distinct()

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context["request"] = self.request
        return context

    def perform_create(self, serializer):
        conversation = serializer.validated_data["conversation"]
        user = self.request.user
        if user not in (conversation.client, conversation.agent):
            raise serializers.ValidationError("Vous ne faites pas partie de cette conversation.")
        if not user_can_access_conversation(user, conversation):
            raise PermissionDenied("Un abonnement actif est requis pour envoyer des messages dans cette conversation.")

        receiver = conversation.agent if user == conversation.client else conversation.client

        now = timezone.now()
        is_delivered = False
        delivered_at = None
        if receiver.is_online:
            is_delivered = True
            delivered_at = now

        message = serializer.save(
            sender=user,
            receiver=receiver,
            is_delivered=is_delivered,
            delivered_at=delivered_at,
        )

        # Couvre les trois cas du cahier des charges (bailleur↔agent,
        # client→agent) avec un seul hook : `receiver` est déjà calculé
        # correctement ci-dessus quel que soit le rôle de l'expéditeur.
        NotificationService.notify(
            recipient=receiver,
            notif_type=Notification.TYPE_NEW_MESSAGE,
            title="Nouveau message",
            body=message.content or "Vous avez reçu une pièce jointe.",
            conversation=conversation,
            data={"conversation_id": str(conversation.id)},
            actor=user,
        )


class MessageAttachmentDownloadView(APIView):
    """GET /api/messages/{id}/attachment/ — seuls les participants de la
    conversation (client/bailleur initiateur ou agent) peuvent télécharger
    la pièce jointe, soit via l'en-tête JWT Authorization, soit via l'URL
    signée cryptographiquement (?sig=...) générée pour les lecteurs médias
    Flutter (CachedNetworkImage, just_audio, video_player, Web)."""

    permission_classes = [permissions.AllowAny]

    def get(self, request, pk):
        from django.core.signing import BadSignature, SignatureExpired, TimestampSigner
        from rest_framework.exceptions import NotAuthenticated

        message = get_object_or_404(Message, pk=pk)
        conversation = message.conversation

        if request.user and request.user.is_authenticated:
            if request.user not in (conversation.client, conversation.agent):
                raise PermissionDenied("Vous ne faites pas partie de cette conversation.")
            if not user_can_access_conversation(request.user, conversation):
                raise PermissionDenied("Un abonnement actif est requis pour télécharger cette pièce jointe.")
        else:
            sig = request.query_params.get("sig", "")
            if not sig:
                raise NotAuthenticated()
            signer = TimestampSigner(salt="messaging.attachment")
            try:
                unsigned_pk = signer.unsign(sig, max_age=86400 * 7)
                if str(unsigned_pk) != str(message.pk):
                    raise NotAuthenticated()
            except (BadSignature, SignatureExpired):
                raise NotAuthenticated()

        if not message.attachment:
            raise Http404
        filename = message.attachment.name.rsplit("/", 1)[-1]
        response = FileResponse(message.attachment.open("rb"), filename=filename)
        response["X-Content-Type-Options"] = "nosniff"
        response["Content-Security-Policy"] = "default-src 'none'; sandbox"
        return response
