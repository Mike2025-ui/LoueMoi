from django.urls import path

from . import views

app_name = "dashboard"

urlpatterns = [
    path("login/", views.DashboardLoginView.as_view(), name="login"),
    path("logout/", views.logout_view, name="logout"),
    path("", views.index, name="index"),
    path("users/", views.users_list, name="users_list"),
    path("users/<int:pk>/", views.user_detail, name="user_detail"),
    path("users/<int:pk>/delete/", views.delete_user, name="delete_user"),
    path("users/<int:pk>/toggle-certificate/", views.toggle_certificate, name="toggle_certificate"),
    path("properties/", views.properties_list, name="properties_list"),
    path("properties/<int:pk>/", views.property_detail, name="property_detail"),
    path("reservations/", views.reservations_list, name="reservations_list"),
    path("conversations/", views.conversations_list, name="conversations_list"),
    path("conversations/<int:pk>/", views.conversation_detail, name="conversation_detail"),
    path("notifications/", views.notifications_list, name="notifications_list"),
    path("notifications/broadcast/", views.broadcast_notification, name="broadcast_notification"),
    path("reviews/", views.reviews_list, name="reviews_list"),
    path("agents/", views.agents_list, name="agents_list"),
    path("activations/", views.pending_activations, name="pending_activations"),
    path("activations/<int:pk>/activate/", views.activate_user, name="activate_user"),
    path("fcm/", views.fcm_list, name="fcm_list"),
    path("statistics/", views.statistics, name="statistics"),
    path("app-settings/", views.app_settings_view, name="app_settings"),
]
