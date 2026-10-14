from django.contrib.auth.decorators import login_required, user_passes_test


def staff_required(view_func):
    """Protège une vue dashboard côté serveur : jamais un simple bouton
    caché côté template. Redirige vers /dashboard/login/ (LOGIN_URL) si
    l'utilisateur n'est pas connecté, ou s'il est connecté mais n'a pas
    is_staff=True — un client/bailleur/agent normal ne passe jamais ce test,
    quelle que soit l'URL qu'il essaie d'atteindre directement."""

    checked = user_passes_test(lambda u: u.is_authenticated and u.is_staff)(view_func)
    return login_required(checked)
