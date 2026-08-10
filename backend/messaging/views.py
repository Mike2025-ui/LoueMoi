from django.db.models import Q
from rest_framework import generics, permissions, serializers, viewsets

from .models import Conversation, Message
from .serializers import ConversationSerializer, MessageSerializer


class ConversationViewSet(viewsets.ModelViewSet):
    """/api/conversations/ — conversations de l'utilisateur connecté,
    côté client ou côté agent."""

    serializer_class = ConversationSerializer
    permission_classes = [permissions.IsAuthenticated]
    http_method_names = ["get", "post", "head", "options"]

    def get_queryset(self):
        user = self.request.user
        return Conversation.objects.filter(Q(client=user) | Q(agent=user))

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context["request"] = self.request
        return context

    def perform_create(self, serializer):
        # get_or_create plutôt que save() : "Contacter l'agent" doit pouvoir
        # être appelé plusieurs fois (sessions différentes, etc.) et retomber
        # sur la même conversation au lieu d'échouer ou d'en créer une copie.
        conversation, _created = Conversation.objects.get_or_create(
            client=self.request.user,
            agent=serializer.validated_data["agent"],
            property=serializer.validated_data.get("property"),
        )
        serializer.instance = conversation


class MessageListCreateView(generics.ListCreateAPIView):
    """GET /api/messages/?conversation=<id>  —  POST /api/messages/"""

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

    def perform_create(self, serializer):
        conversation = serializer.validated_data["conversation"]
        user = self.request.user
        if user not in (conversation.client, conversation.agent):
            raise serializers.ValidationError("Vous ne faites pas partie de cette conversation.")
        receiver = conversation.agent if user == conversation.client else conversation.client
        serializer.save(sender=user, receiver=receiver)
