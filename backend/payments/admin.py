from django.contrib import admin
from .models import Subscription


@admin.register(Subscription)
class SubscriptionAdmin(admin.ModelAdmin):
    list_display = (
        "reference",
        "user",
        "plan",
        "amount",
        "payment_method",
        "status",
        "started_at",
        "expires_at",
        "created_at",
    )
    list_filter = ("plan", "status", "payment_method", "created_at")
    search_fields = ("reference", "user__phone", "user__first_name", "user__last_name")
    readonly_fields = ("created_at", "updated_at")
    actions = ["activate_selected_subscriptions"]

    @admin.action(description="Activer les abonnements sélectionnés (30 jours)")
    def activate_selected_subscriptions(self, request, queryset):
        for sub in queryset:
            sub.activate_for_30_days()
        self.message_user(request, f"{queryset.count()} abonnement(s) activé(s) avec succès.")
