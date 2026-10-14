from django.urls import path

from .views import BailleurDashboardView, BailleurPropertiesView, BailleurSearchView

urlpatterns = [
    path("bailleur/dashboard/", BailleurDashboardView.as_view(), name="bailleur-dashboard"),
    path("bailleur/properties/", BailleurPropertiesView.as_view(), name="bailleur-properties"),
    path("bailleurs/", BailleurSearchView.as_view(), name="bailleur-search"),
]
