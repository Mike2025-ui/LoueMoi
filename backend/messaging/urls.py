from rest_framework.routers import DefaultRouter

from django.urls import path, include

from .views import ConversationViewSet, MessageListCreateView

router = DefaultRouter()
router.register("conversations", ConversationViewSet, basename="conversation")

urlpatterns = [
    path("messages/", MessageListCreateView.as_view(), name="messages"),
    path("", include(router.urls)),
]
