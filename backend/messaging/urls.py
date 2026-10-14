from rest_framework.routers import DefaultRouter

from django.urls import path, include

from .views import ConversationViewSet, MessageAttachmentDownloadView, MessageListCreateView

router = DefaultRouter()
router.register("conversations", ConversationViewSet, basename="conversation")

urlpatterns = [
    path("messages/", MessageListCreateView.as_view(), name="messages"),
    path(
        "messages/<int:pk>/attachment/",
        MessageAttachmentDownloadView.as_view(),
        name="message-attachment",
    ),
    path("", include(router.urls)),
]
