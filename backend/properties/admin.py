from django.contrib import admin

from .models import Favorite, Property


@admin.register(Property)
class PropertyAdmin(admin.ModelAdmin):
    list_display = [
        "title", "type", "transaction_type", "status", "commune", "district",
        "price", "agent", "latitude", "longitude",
        "views_count", "favorites_count", "created_at",
    ]
    # `status` est éditable directement dans la liste : c'est ici que
    # l'administration désactive une annonce après publication (jamais
    # avant — il n'y a pas d'étape d'approbation).
    list_editable = ["status"]
    list_filter = ["type", "transaction_type", "status", "is_future"]
    search_fields = [
        "title", "commune", "district",
        "agent__phone", "agent__first_name", "agent__last_name",
    ]
    readonly_fields = ["views_count", "favorites_count", "created_at", "updated_at"]


@admin.register(Favorite)
class FavoriteAdmin(admin.ModelAdmin):
    list_display = ["user", "property", "created_at"]
