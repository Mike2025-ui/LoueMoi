from django.urls import path

from .views import (
    DeviceTokenDeactivateView,
    DeviceTokenRegisterView,
    MarkAllNotificationsAsReadView,
    MarkNotificationAsReadView,
    NotificationListView,
    UnreadCountView,
)

urlpatterns = [
    path("notifications/", NotificationListView.as_view(), name="notifications"),
    path(
        "notifications/unread-count/",
        UnreadCountView.as_view(),
        name="notifications-unread-count",
    ),
    path(
        "notifications/read-all/",
        MarkAllNotificationsAsReadView.as_view(),
        name="notifications-read-all",
    ),
    path(
        "notifications/<int:pk>/read/",
        MarkNotificationAsReadView.as_view(),
        name="notification-read",
    ),
    path("devices/", DeviceTokenRegisterView.as_view(), name="device-register"),
    path(
        "devices/deactivate/",
        DeviceTokenDeactivateView.as_view(),
        name="device-deactivate",
    ),
]
