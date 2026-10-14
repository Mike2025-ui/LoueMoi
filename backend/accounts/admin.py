from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as DjangoUserAdmin

from .models import PasswordResetOTP, User


@admin.register(User)
class UserAdmin(DjangoUserAdmin):
    ordering = ["-date_joined"]
    list_display = [
        "phone", "first_name", "last_name", "role",
        "is_staff", "is_superuser", "is_active", "last_login", "date_joined",
    ]
    list_filter = ["role", "is_staff", "is_superuser", "is_active"]
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
        # Absentes auparavant du formulaire (fieldsets personnalisé ne
        # montrait que les champs listés ci-dessus) : la date d'inscription
        # et la dernière connexion existent bien en base (AbstractBaseUser)
        # mais restaient invisibles côté admin.
        ("Dates", {"fields": ("last_login", "date_joined")}),
    )
    readonly_fields = ["date_joined", "last_login"]
    add_fieldsets = (
        (
            None,
            {
                "classes": ("wide",),
                "fields": ("phone", "first_name", "last_name", "role", "password1", "password2"),
            },
        ),
    )


@admin.register(PasswordResetOTP)
class PasswordResetOTPAdmin(admin.ModelAdmin):
    """Lecture seule : `code_hash` est un hash, jamais le code en clair —
    rien d'éditable ici n'a de sens métier, cet écran sert uniquement
    d'audit (qui a demandé un code, quand, combien de tentatives)."""

    list_display = ["user", "created_at", "expires_at", "attempts", "is_used"]
    list_filter = ["is_used"]
    search_fields = ["user__phone", "user__first_name", "user__last_name"]
    readonly_fields = ["user", "code_hash", "created_at", "expires_at", "attempts", "is_used"]

    def has_add_permission(self, request):
        return False
