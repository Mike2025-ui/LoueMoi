"""Toutes les routes API vivent sous /api/, avec exactement les chemins
définis dans lib/core/network/api_endpoints.dart côté Flutter."""

from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.urls import include, path

from .media_views import serve_media
from dashboard.views import public_app_config_api

urlpatterns = [
    path("admin/", admin.site.urls),
    path("dashboard/", include("dashboard.urls")),
    path("api/config/app-settings/", public_app_config_api, name="public_app_config"),
    path("api/", include("accounts.urls")),
    path("api/", include("agents.urls")),
    path("api/", include("bailleurs.urls")),
    path("api/", include("properties.urls")),
    path("api/", include("reviews.urls")),
    path("api/", include("reservations.urls")),
    path("api/", include("messaging.urls")),
    path("api/", include("notifications.urls")),
    path("api/payments/", include("payments.urls")),
]

if settings.DEBUG:
    # view=serve_media (au lieu de la vue par défaut django.views.static.
    # serve) : seule cette vue gère les requêtes HTTP Range, indispensables
    # à la lecture vidéo réseau (voir config/media_views.py pour la cause
    # exacte). N'affecte que le développement/LAN — DEBUG=False en
    # production, où les fichiers media sont servis autrement.
    urlpatterns += static(settings.MEDIA_URL, view=serve_media, document_root=settings.MEDIA_ROOT)
