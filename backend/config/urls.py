"""Toutes les routes API vivent sous /api/, avec exactement les chemins
définis dans lib/core/network/api_endpoints.dart côté Flutter."""

from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.urls import include, path, re_path

from .media_views import serve_media
from dashboard.views import public_app_config_api

urlpatterns = [
    path("admin/", admin.site.urls),
    path("dashboard/", include("dashboard.urls")),
    path("api/config/app-settings/", public_app_config_api, name="public_app_config"),
    path("api/", include("accounts.urls")),
    path("api/", include("properties.urls")),
    path("api/", include("reviews.urls")),
    path("api/", include("reservations.urls")),
    path("api/", include("messaging.urls")),
    path("api/", include("notifications.urls")),
    # Fallback pour servir les fichiers médias via Django/Gunicorn si Nginx proxy_pass
    # ou si les fichiers médias sont sur le volume applicatif
    re_path(r"^media/(?P<path>.*)$", serve_media, {"document_root": settings.MEDIA_ROOT}),
]
