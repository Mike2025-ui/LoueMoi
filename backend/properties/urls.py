from django.urls import path
from rest_framework.routers import DefaultRouter

from .views import MyPropertiesView, PropertyNearbyView, PropertyViewSet

router = DefaultRouter()
router.register("properties", PropertyViewSet, basename="property")

urlpatterns = [
    path("agent/properties/", MyPropertiesView.as_view(), name="agent-properties"),
    # Doit être déclaré AVANT *router.urls : sinon le pattern dynamique
    # properties/<pk>/ du DefaultRouter capturerait "nearby" comme une
    # valeur de pk et cette route ne serait jamais atteinte.
    path("properties/nearby/", PropertyNearbyView.as_view(), name="properties-nearby"),
    *router.urls,
]
