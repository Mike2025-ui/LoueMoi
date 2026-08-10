from rest_framework import permissions


class IsAgent(permissions.BasePermission):
    """Autorise uniquement les utilisateurs `role=agent`. Réutilisable par
    toute app ayant besoin de restreindre une action aux agents (properties,
    et plus tard reservations/messaging si nécessaire)."""

    message = "Seul un agent immobilier peut effectuer cette action."

    def has_permission(self, request, view):
        user = request.user
        return bool(user and user.is_authenticated and user.role == user.ROLE_AGENT)
