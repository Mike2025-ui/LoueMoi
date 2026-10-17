from django.db.models import Q
from django.http import FileResponse, Http404
from django.shortcuts import get_object_or_404
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
        # Ne renvoie que les conversations qui contiennent au moins un message réel
        # pour éviter d'afficher des conversations fantômes non démarrées
        return (
            Conversation.objects.filter(Q(client=user) | Q(agent=user))
            .filter(messages__isnull=False)
            .distinct()
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
        conversation.messages.filter(is_read=False).exclude(sender=request.user).update(
            is_read=True
        )
        Notification.objects.filter(
            conversation=conversation,
            recipient=request.user,
            type=Notification.TYPE_NEW_MESSAGE,
        ).update(is_read=True)
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
        message = serializer.save(sender=user, receiver=receiver)

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
    la pièce jointe. Jamais servi via l'URL MEDIA_URL publique brute, qui
    serait accessible à quiconque connaît/devine l'URL sans authentification."""

    permission_classes = [permissions.IsAuthenticated]

    def get(self, request, pk):
        message = get_object_or_404(Message, pk=pk)
        conversation = message.conversation
        if request.user not in (conversation.client, conversation.agent):
            raise PermissionDenied("Vous ne faites pas partie de cette conversation.")
        if not message.attachment:
            raise Http404
        filename = message.attachment.name.rsplit("/", 1)[-1]
        return FileResponse(message.attachment.open("rb"), filename=filename)
