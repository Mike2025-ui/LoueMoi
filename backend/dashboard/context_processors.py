from accounts.models import User


def dashboard_context(request):
    """Injecte les compteurs globaux du dashboard pour l'ensemble des templates."""
    if not getattr(request, "user", None) or not request.user.is_authenticated or not request.user.is_staff:
        return {}

    pending_activations_count = User.objects.filter(
        role__in=[User.ROLE_BAILLEUR, User.ROLE_AGENT],
        is_approved=False,
    ).count()

    return {
        "pending_activations_count": pending_activations_count,
    }

