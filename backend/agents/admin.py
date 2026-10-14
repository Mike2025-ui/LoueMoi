from django.contrib import admin

from .models import AgentProfile


@admin.register(AgentProfile)
class AgentProfileAdmin(admin.ModelAdmin):
    list_display = ["user", "agency_name", "certification_status", "is_verified", "rating"]
    list_filter = ["certification_status", "is_verified"]
    search_fields = ["user__first_name", "user__last_name", "user__phone", "agency_name"]
    # is_verified reste éditable directement ici pour une vérification
    # manuelle ponctuelle (comportement déjà existant, conservé tel quel) —
    # mais le workflow normal (demande de l'agent → décision de l'admin)
    # passe par les actions ci-dessous, qui mettent toujours
    # certification_status ET is_verified à jour ensemble, pour qu'ils ne
    # divergent jamais dans ce chemin.
    list_editable = ["is_verified"]
    actions = ["approve_certification", "reject_certification"]

    @admin.action(description="Approuver la certification (marque aussi comme vérifié)")
    def approve_certification(self, request, queryset):
        updated = queryset.update(
            certification_status=AgentProfile.CERTIFICATION_APPROVED, is_verified=True
        )
        self.message_user(request, f"{updated} profil(s) certifié(s).")

    @admin.action(description="Refuser la certification")
    def reject_certification(self, request, queryset):
        updated = queryset.update(
            certification_status=AgentProfile.CERTIFICATION_REJECTED, is_verified=False
        )
        self.message_user(request, f"{updated} demande(s) refusée(s).")
