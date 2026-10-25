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
    actions = ["activate_selected_subscriptions", "cancel_selected_subscriptions", "expire_selected_subscriptions"]

    @admin.action(description="Activer les abonnements sélectionnés (30 jours)")
    def activate_selected_subscriptions(self, request, queryset):
        for sub in queryset:
            sub.activate_for_30_days()
        self.message_user(request, f"{queryset.count()} abonnement(s) activé(s) avec succès.")

    @admin.action(description="Annuler les abonnements sélectionnés (révoque les accès immédiatement)")
    def cancel_selected_subscriptions(self, request, queryset):
        for sub in queryset:
            sub.cancel_and_revoke()
        self.message_user(request, f"{queryset.count()} abonnement(s) annulé(s) avec succès.")

    @admin.action(description="Marquer comme expirés les abonnements sélectionnés")
    def expire_selected_subscriptions(self, request, queryset):
        for sub in queryset:
            sub.expire_and_revoke()
        self.message_user(request, f"{queryset.count()} abonnement(s) expiré(s) avec succès.")

    def save_model(self, request, obj, form, change):
        if "status" in form.changed_data:
            if obj.status == Subscription.STATUS_ACTIVE:
                obj.activate_for_30_days()
                return
            elif obj.status == Subscription.STATUS_CANCELLED:
                obj.cancel_and_revoke()
                return
            elif obj.status == Subscription.STATUS_EXPIRED:
                obj.expire_and_revoke()
                return
        super().save_model(request, obj, form, change)

