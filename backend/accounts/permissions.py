from rest_framework import permissions


class IsAgent(permissions.BasePermission):
    """Autorise uniquement les utilisateurs `role=agent` actifs."""

    message = "Seul un agent immobilier peut effectuer cette action."

    def has_permission(self, request, view):
        user = request.user
        return bool(
            user
            and user.is_authenticated
            and user.is_active
            and (user.role == user.ROLE_AGENT or user.is_staff)
        )


class IsBailleur(permissions.BasePermission):
    """Autorise uniquement les utilisateurs `role=bailleur` actifs."""

    message = "Seul un bailleur peut effectuer cette action."

    def has_permission(self, request, view):
        user = request.user
        return bool(
            user
            and user.is_authenticated
            and user.is_active
            and (user.role == user.ROLE_BAILLEUR or user.is_staff)
        )


class CanOwnProperties(permissions.BasePermission):
    """Autorise `role=agent` OU `role=bailleur` approuvé — les deux seuls rôles
    habilités à publier/posséder des annonces. Exige que le compte ait été
    approuvé par l'administrateur (is_approved=True) et soit actif."""

    message = "Votre compte doit être activé par un administrateur pour publier ou gérer une annonce."

    def has_permission(self, request, view):
        user = request.user
        return bool(
            user
            and user.is_authenticated
            and user.is_active
            and user.can_own_properties
            and (user.is_approved or user.is_staff)
        )


class HasActiveSubscription(permissions.BasePermission):
    """Autorise uniquement les utilisateurs connectés possédant un abonnement actif (ou administrateurs)."""

    message = "Un abonnement actif est requis pour effectuer cette recherche."

    def has_permission(self, request, view):
        user = request.user
        return bool(
            user
            and user.is_authenticated
            and user.is_active
            and (user.has_active_subscription or user.is_staff)
        )

