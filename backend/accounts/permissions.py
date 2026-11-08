from rest_framework import permissions


class IsAgent(permissions.BasePermission):
    """Rôle agent déprécié — seuls les administrateurs LoueMoi centralisent les opérations."""

    message = "Seul un administrateur LoueMoi peut effectuer cette action."

    def has_permission(self, request, view):
        user = request.user
        return bool(
            user
            and user.is_authenticated
            and user.is_active
            and (user.is_staff or user.is_superuser or getattr(user, "role", "") == getattr(user, "ROLE_ADMIN", "admin"))
        )


class IsBailleur(permissions.BasePermission):
    """Rôle bailleur déprécié — seuls les administrateurs LoueMoi centralisent les opérations."""

    message = "Seul un administrateur LoueMoi peut effectuer cette action."

    def has_permission(self, request, view):
        user = request.user
        return bool(
            user
            and user.is_authenticated
            and user.is_active
            and (user.is_staff or user.is_superuser or getattr(user, "role", "") == getattr(user, "ROLE_ADMIN", "admin"))
        )


class CanOwnProperties(permissions.BasePermission):
    """Seuls les administrateurs LoueMoi (is_staff / is_superuser / role='admin')
    sont habilités à publier, modifier ou gérer des annonces.
    Les clients et utilisateurs tiers ne peuvent pas publier d'annonces directement."""

    message = "Seul un administrateur LoueMoi peut publier ou gérer une annonce."

    def has_permission(self, request, view):
        user = request.user
        return bool(
            user
            and user.is_authenticated
            and user.is_active
            and (user.is_staff or user.is_superuser or getattr(user, "role", "") == getattr(user, "ROLE_ADMIN", "admin"))
        )


class HasActiveSubscription(permissions.BasePermission):
    """Modèle LoueMoi 100% direct et gratuit : aucun abonnement requis."""

    message = "Connexion requise."

    def has_permission(self, request, view):
        user = request.user
        return bool(
            user
            and user.is_authenticated
            and user.is_active
        )

