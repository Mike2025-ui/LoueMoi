from django.urls import path

from .views import AgentDashboardView

urlpatterns = [
    path("agent/dashboard/", AgentDashboardView.as_view(), name="agent-dashboard"),
]
