from django.urls import path
from rest_framework.routers import DefaultRouter

from .views import MyPropertiesView, PropertyViewSet

router = DefaultRouter()
router.register("properties", PropertyViewSet, basename="property")

urlpatterns = [
    path("agent/properties/", MyPropertiesView.as_view(), name="agent-properties"),
    *router.urls,
]
