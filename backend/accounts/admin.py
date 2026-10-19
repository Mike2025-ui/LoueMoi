from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as DjangoUserAdmin
from django.db import transaction

from .models import PasswordResetOTP, User


@admin.register(User)
class UserAdmin(DjangoUserAdmin):
    ordering = ["-date_joined"]
    list_display = [
        "phone", "first_name", "last_name", "role",
        "is_approved", "is_verified",
        "is_staff", "is_superuser", "is_active", "last_login", "date_joined",
    ]
    list_editable = ["is_approved", "is_verified"]
    list_filter = ["role", "is_approved", "is_verified", "is_staff", "is_superuser", "is_active"]
    search_fields = ["phone", "first_name", "last_name"]
    fieldsets = (
        (None, {"fields": ("phone", "password")}),
        ("Informations", {"fields": ("first_name", "last_name", "whatsapp", "photo")}),
        # C'est ici que l'administration peut créer/promouvoir un agent —
        # jamais possible depuis l'inscription publique côté Flutter.
        ("Rôle", {"fields": ("role",)}),
        (
            "Statut & Validation",
            {"fields": ("is_approved", "is_verified", "activation_requested", "activation_requested_at")},
        ),
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

    def delete_model(self, request, obj):
        """Permet à l'administrateur de supprimer n'importe quel utilisateur dans le dashboard,
        même s'il possède des annonces ou des réservations protégées par PROTECT."""
        with transaction.atomic():
            for prop in obj.properties.all():
                prop.reservations.all().delete()
                prop.delete()
            obj.delete()

    def delete_queryset(self, request, queryset):
        """Suppression en masse dans le dashboard sans erreur ProtectedError."""
        with transaction.atomic():
            for user in queryset:
                for prop in user.properties.all():
                    prop.reservations.all().delete()
                    prop.delete()
                user.delete()


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
