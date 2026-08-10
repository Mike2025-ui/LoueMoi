"""Toutes les routes API vivent sous /api/, avec exactement les chemins
définis dans lib/core/network/api_endpoints.dart côté Flutter."""

from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.urls import include, path

urlpatterns = [
    path("admin/", admin.site.urls),
    path("api/", include("accounts.urls")),
    path("api/", include("agents.urls")),
    path("api/", include("properties.urls")),
    path("api/", include("reviews.urls")),
    path("api/", include("reservations.urls")),
    path("api/", include("messaging.urls")),
]

if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
