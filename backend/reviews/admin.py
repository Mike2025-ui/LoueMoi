from django.contrib import admin

from .models import Review


@admin.register(Review)
class ReviewAdmin(admin.ModelAdmin):
    list_display = ["property", "user", "owner", "rating", "created_at"]
    list_filter = ["rating"]
    search_fields = [
        "property__title",
        "user__phone", "user__first_name", "user__last_name",
        "property__agent__phone", "property__agent__first_name", "property__agent__last_name",
    ]
    readonly_fields = ["created_at"]

    @admin.display(description="Propriétaire du bien")
    def owner(self, obj):
        return obj.property.agent
