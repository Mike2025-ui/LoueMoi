from django.contrib import admin

from .models import AgentProfile


@admin.register(AgentProfile)
class AgentProfileAdmin(admin.ModelAdmin):
    list_display = ["user", "agency_name", "is_verified", "rating"]
    list_filter = ["is_verified"]
    search_fields = ["user__first_name", "user__last_name", "user__phone", "agency_name"]
    # is_verified se contrôle uniquement ici (Django Admin), jamais via l'API agent.
    list_editable = ["is_verified"]
