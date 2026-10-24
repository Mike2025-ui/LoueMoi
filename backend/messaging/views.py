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


class ConversationViewSet(viewsets.ModelViewSet):
    """/api/conversations/ — conversations de l'utilisateur connecté,
    côté client/bailleur (initiateur) ou côté agent."""

    serializer_class = ConversationSerializer
    permission_classes = [permissions.IsAuthenticated]
    http_method_names = ["get", "post", "delete", "head", "options"]

    def get_queryset(self):
        user = self.request.user
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


    @action(detail=True, methods=["post"], url_path="mark-read")
    def mark_read(self, request, pk=None):
        """POST /api/conversations/{id}/mark-read/ — marque comme lus tous
        les messages de la conversation reçus par l'utilisateur connecté.
        Appelé à l'ouverture de ConversationScreen côté Flutter : sans ça,
        `unread_count` (et donc le badge de l'onglet Messages) ne redescend
        jamais, même après lecture."""
        conversation = self.get_object()
        now = timezone.now()
        conversation.messages.filter(is_read=False).exclude(sender=request.user).update(
            is_read=True,
            is_delivered=True,
            read_at=now,
            delivered_at=now,
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
        queryset = Message.objects.filter(
            conversation__client=self.request.user
        ) | Message.objects.filter(conversation__agent=self.request.user)
        if conversation_id:
            queryset = queryset.filter(conversation_id=conversation_id)
            # Marquer automatiquement comme délivrés (2 traits gris) les messages reçus
            Message.objects.filter(
                conversation_id=conversation_id,
                receiver=self.request.user,
                is_delivered=False,
            ).update(is_delivered=True, delivered_at=timezone.now())
        return queryset.distinct()

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context["request"] = self.request
        return context

    def perform_create(self, serializer):
        conversation = serializer.validated_data["conversation"]
        user = self.request.user
        if user not in (conversation.client, conversation.agent):
            raise serializers.ValidationError("Vous ne faites pas partie de cette conversation.")
        receiver = conversation.agent if user == conversation.client else conversation.client

        # Un agent ou bailleur ne peut pas envoyer de message à un client sans abonnement actif
        if user.role in ("agent", "bailleur") and receiver.role == "client":
            if not user.has_active_subscription:
                raise PermissionDenied("Un abonnement actif est requis pour contacter ou répondre à un client.")

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
