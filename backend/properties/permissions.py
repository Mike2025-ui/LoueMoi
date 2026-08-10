from rest_framework import permissions


class IsPropertyOwnerOrReadOnly(permissions.BasePermission):
    """Lecture libre (déjà garantie par IsAuthenticatedOrReadOnly en amont) ;
    modification/suppression réservées à l'agent propriétaire de l'annonce.
    Un agent A ne peut donc jamais toucher aux annonces de l'agent B."""

    message = "Vous ne pouvez modifier ou supprimer que vos propres annonces."

    def has_object_permission(self, request, view, obj):
        if request.method in permissions.SAFE_METHODS:
            return True
        return obj.agent_id == request.user.id
