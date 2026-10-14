from django.urls import path

from .views import (
    AgentCertificationRequestView,
    AgentDashboardView,
    AgentProfileMeView,
    AgentSearchView,
)

urlpatterns = [
    path("agent/dashboard/", AgentDashboardView.as_view(), name="agent-dashboard"),
    path("agent/profile/", AgentProfileMeView.as_view(), name="agent-profile-me"),
    path(
        "agent/certification/request/",
        AgentCertificationRequestView.as_view(),
        name="agent-certification-request",
    ),
    path("agents/", AgentSearchView.as_view(), name="agent-search"),
]
