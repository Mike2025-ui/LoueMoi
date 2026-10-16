from django.shortcuts import get_object_or_404
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import DeviceToken, Notification
from .serializers import DeviceTokenSerializer, NotificationSerializer


class NotificationListView(generics.ListAPIView):
    """GET /api/notifications/ — uniquement les notifications de
    l'utilisateur connecté, jamais celles d'un autre (client, bailleur ou
    agent confondus). Exclut les messages de chat (qui vivent exclusivement dans l'onglet Messages)."""

    serializer_class = NotificationSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Notification.objects.filter(recipient=self.request.user).exclude(
            type=Notification.TYPE_NEW_MESSAGE
        )


class UnreadCountView(APIView):
    """GET /api/notifications/unread-count/ — pour le badge de la cloche."""

    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        count = (
            Notification.objects.filter(recipient=request.user, is_read=False)
            .exclude(type=Notification.TYPE_NEW_MESSAGE)
            .count()
        )
        return Response({"unread_count": count})


class MarkNotificationAsReadView(APIView):
    """POST /api/notifications/{id}/read/"""

    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, pk):
        notification = get_object_or_404(Notification, pk=pk, recipient=request.user)
        notification.is_read = True
        notification.save(update_fields=["is_read"])
        return Response(NotificationSerializer(notification).data)


class MarkAllNotificationsAsReadView(APIView):
    """POST /api/notifications/read-all/"""

    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        Notification.objects.filter(recipient=request.user, is_read=False).exclude(
            type=Notification.TYPE_NEW_MESSAGE
        ).update(is_read=True)
        return Response({"detail": "Toutes les notifications ont été marquées comme lues."})


class DeviceTokenRegisterView(APIView):
    """POST /api/devices/ — {"token": "...", "platform": "android"|"ios"}
    Associe le token à l'utilisateur authentifié. `token` est unique
    globalement : si le même appareil se reconnecte avec un compte
    différent (logout/login), le token est simplement réassigné plutôt que
    de lever une erreur d'intégrité."""

    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        token = request.data.get("token")
        platform = request.data.get("platform")
        if not token or platform not in (DeviceToken.PLATFORM_ANDROID, DeviceToken.PLATFORM_IOS):
            return Response(
                {"detail": "'token' et 'platform' ('android' ou 'ios') sont requis."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        device, created = DeviceToken.objects.update_or_create(
            token=token,
            defaults={"user": request.user, "platform": platform, "is_active": True},
        )
        return Response(
            DeviceTokenSerializer(device).data,
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK,
        )


class DeviceTokenDeactivateView(APIView):
    """POST /api/devices/deactivate/ — {"token": "..."} (logout, ou FCM
    signale un token invalide). Ne supprime jamais l'historique des
    notifications déjà créées, seulement le token."""

    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        token = request.data.get("token")
        if not token:
            return Response({"detail": "'token' est requis."}, status=status.HTTP_400_BAD_REQUEST)
        DeviceToken.objects.filter(token=token, user=request.user).update(is_active=False)
        return Response({"detail": "Token désactivé."})
