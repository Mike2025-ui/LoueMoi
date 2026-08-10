from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as DjangoUserAdmin

from .models import User


@admin.register(User)
class UserAdmin(DjangoUserAdmin):
    ordering = ["-date_joined"]
    list_display = ["phone", "first_name", "last_name", "role", "is_staff"]
    list_filter = ["role", "is_staff", "is_active"]
    search_fields = ["phone", "first_name", "last_name"]
    fieldsets = (
        (None, {"fields": ("phone", "password")}),
        ("Informations", {"fields": ("first_name", "last_name", "whatsapp", "photo")}),
        # C'est ici que l'administration peut créer/promouvoir un agent —
        # jamais possible depuis l'inscription publique côté Flutter.
        ("Rôle", {"fields": ("role",)}),
        (
            "Permissions",
            {"fields": ("is_active", "is_staff", "is_superuser", "groups", "user_permissions")},
        ),
    )
    add_fieldsets = (
        (
            None,
            {
                "classes": ("wide",),
                "fields": ("phone", "first_name", "last_name", "role", "password1", "password2"),
            },
        ),
    )
