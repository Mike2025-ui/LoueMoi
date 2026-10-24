from django.urls import path
from rest_framework_simplejwt.views import TokenRefreshView

from .views import (
    DeactivateAccountView,
    LoginView,
    LogoutView,
    MeView,
    PasswordResetConfirmView,
    PasswordResetRequestView,
    RegisterView,
    RequestActivationView,
    UserPresenceView,
)

urlpatterns = [
    path("auth/login/", LoginView.as_view(), name="auth-login"),
    path("auth/register/", RegisterView.as_view(), name="auth-register"),
    path("auth/request-activation/", RequestActivationView.as_view(), name="auth-request-activation"),
    path("auth/refresh/", TokenRefreshView.as_view(), name="auth-refresh"),
    path("auth/logout/", LogoutView.as_view(), name="auth-logout"),
    path(
        "auth/password-reset/request/",
        PasswordResetRequestView.as_view(),
        name="password-reset-request",
    ),
    path(
        "auth/password-reset/confirm/",
        PasswordResetConfirmView.as_view(),
        name="password-reset-confirm",
    ),
    path("users/me/", MeView.as_view(), name="users-me"),
    path("users/me/deactivate/", DeactivateAccountView.as_view(), name="users-me-deactivate"),
    path("users/presence/", UserPresenceView.as_view(), name="user-presence"),
]
