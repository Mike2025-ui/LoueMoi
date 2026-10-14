from rest_framework import permissions


class IsAgent(permissions.BasePermission):
    """Autorise uniquement les utilisateurs `role=agent`. Réutilisable par
    toute app ayant besoin de restreindre une action aux agents (properties,
    et plus tard reservations/messaging si nécessaire)."""

    message = "Seul un agent immobilier peut effectuer cette action."

    def has_permission(self, request, view):
        user = request.user
        return bool(user and user.is_authenticated and user.role == user.ROLE_AGENT)


class IsBailleur(permissions.BasePermission):
    """Autorise uniquement les utilisateurs `role=bailleur`."""

    message = "Seul un bailleur peut effectuer cette action."

    def has_permission(self, request, view):
        user = request.user
        return bool(user and user.is_authenticated and user.role == user.ROLE_BAILLEUR)


class CanOwnProperties(permissions.BasePermission):
    """Autorise `role=agent` OU `role=bailleur` — les deux seuls rôles
    habilités à publier/posséder des annonces. Rôles strictement
    indépendants : cette permission ne crée aucune délégation entre eux,
    elle vérifie juste que l'appelant est l'un ou l'autre."""

    message = "Seuls un agent immobilier ou un bailleur peuvent publier une annonce."

    def has_permission(self, request, view):
        user = request.user
        return bool(user and user.is_authenticated and user.can_own_properties)
