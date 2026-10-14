"""Dashboard administrateur personnalisé — vues Django classiques
(templates + sessions), jamais de JWT ici. Chaque vue est protégée
individuellement par @staff_required (voir dashboard/decorators.py),
jamais uniquement par un lien caché côté template.

Aucune statistique n'est codée en dur : chaque nombre affiché correspond
à un QuerySet réellement exécuté (voir dashboard/tests.py qui compare les
chiffres affichés à User.objects.count() etc.)."""

from django.contrib.auth import views as auth_views
from django.core.paginator import Paginator
from django.db.models import Count, OuterRef, Q, Subquery
from django.shortcuts import get_object_or_404, redirect, render
from django.urls import reverse_lazy

from accounts.models import User
from agents.models import AgentProfile
from messaging.models import Conversation, Message
from notifications.models import DeviceToken, Notification
from properties.models import Property
from reservations.models import Reservation
from reviews.models import Review

from .decorators import staff_required

PAGE_SIZE = 25


class DashboardLoginView(auth_views.LoginView):
    """Réutilise le formulaire d'authentification Django standard (même
    mécanisme que /admin/login/, aucune nouvelle authentification créée) —
    seul le template change pour rester cohérent avec l'identité LoueMoi.

    Jamais de session laissée active pour un compte non-staff sur cette
    page : sans ça, un client/bailleur/agent qui se connecte ici obtiendrait
    une session Django valide, puis rebondirait indéfiniment entre "/" (403
    via @staff_required) et cette page (redirect_authenticated_user) — boucle
    de redirection. On déconnecte donc explicitement tout compte non-staff
    avant même d'afficher/traiter le formulaire."""

    template_name = "dashboard/login.html"

    def dispatch(self, request, *args, **kwargs):
        if request.user.is_authenticated:
            if request.user.is_staff:
                return redirect("dashboard:index")
            from django.contrib.auth import logout

            logout(request)
        return super().dispatch(request, *args, **kwargs)

    def form_valid(self, form):
        response = super().form_valid(form)
        if not self.request.user.is_staff:
            from django.contrib.auth import logout

            logout(self.request)
            form.add_error(None, "Ce compte n'est pas autorisé à accéder au dashboard administrateur.")
            return self.form_invalid(form)
        return response

    def get_success_url(self):
        return self.get_redirect_url() or str(reverse_lazy("dashboard:index"))


@staff_required
def logout_view(request):
    from django.contrib.auth import logout

    logout(request)
    return redirect("dashboard:login")


def _paginate(request, queryset, page_size=PAGE_SIZE):
    paginator = Paginator(queryset, page_size)
    return paginator.get_page(request.GET.get("page"))


def _querystring(request):
    """Préserve les filtres/recherche actifs dans les liens de pagination
    (?q=...&role=agent&page=2) — sans ça, changer de page réinitialiserait
    silencieusement tous les filtres appliqués."""
    params = request.GET.copy()
    params.pop("page", None)
    encoded = params.urlencode()
    return f"{encoded}&" if encoded else ""


@staff_required
def index(request):
    """Tableau de bord — uniquement des agrégats réellement calculés."""
    stats = {
        "users_total": User.objects.count(),
        "clients": User.objects.filter(role=User.ROLE_CLIENT).count(),
        "bailleurs": User.objects.filter(role=User.ROLE_BAILLEUR).count(),
        "agents": User.objects.filter(role=User.ROLE_AGENT).count(),
        "properties_total": Property.objects.count(),
        "properties_disponible": Property.objects.filter(status="disponible").count(),
        "properties_occupee": Property.objects.filter(status="occupee").count(),
        "reservations_total": Reservation.objects.count(),
        "reservations_en_cours": Reservation.objects.filter(status="enCours").count(),
        "conversations_total": Conversation.objects.count(),
        "messages_total": Message.objects.count(),
        "notifications_total": Notification.objects.count(),
        "notifications_non_lues": Notification.objects.filter(is_read=False).count(),
        "reviews_total": Review.objects.count(),
    }

    # Activité récente : fusion d'événements réellement horodatés
    # (created_at existe sur chacun de ces modèles), triés ensemble. Aucun
    # événement fabriqué — uniquement ce que created_at atteste vraiment.
    events = []
    for u in User.objects.order_by("-date_joined")[:5]:
        events.append({"type": "Nouvel utilisateur", "label": str(u), "when": u.date_joined, "role": u.role})
    for p in Property.objects.select_related("agent").order_by("-created_at")[:5]:
        events.append({"type": "Nouvelle propriété", "label": p.title, "when": p.created_at, "role": str(p.agent)})
    for r in Reservation.objects.select_related("property", "user").order_by("-created_at")[:5]:
        events.append({"type": "Nouvelle réservation", "label": str(r.property), "when": r.created_at, "role": str(r.user)})
    for m in Message.objects.select_related("sender", "conversation").order_by("-created_at")[:5]:
        events.append({"type": "Nouveau message", "label": (m.content[:40] or f"[{m.get_attachment_type_display()}]"), "when": m.created_at, "role": str(m.sender)})
    for n in Notification.objects.select_related("recipient").order_by("-created_at")[:5]:
        events.append({"type": "Nouvelle notification", "label": n.get_type_display(), "when": n.created_at, "role": str(n.recipient)})
    for rv in Review.objects.select_related("user", "property").order_by("-created_at")[:5]:
        events.append({"type": "Nouvel avis", "label": str(rv.property), "when": rv.created_at, "role": str(rv.user)})

    events.sort(key=lambda e: e["when"], reverse=True)
    events = events[:15]

    return render(request, "dashboard/index.html", {"stats": stats, "events": events, "active": "index"})


@staff_required
def users_list(request):
    qs = User.objects.all()
    role = request.GET.get("role", "")
    active = request.GET.get("active", "")
    q = request.GET.get("q", "")
    if role:
        qs = qs.filter(role=role)
    if active == "1":
        qs = qs.filter(is_active=True)
    elif active == "0":
        qs = qs.filter(is_active=False)
    if q:
        qs = qs.filter(
            Q(phone__icontains=q) | Q(first_name__icontains=q) | Q(last_name__icontains=q)
        )
    page = _paginate(request, qs)
    return render(
        request,
        "dashboard/users_list.html",
        {
            "page_obj": page, "active": "users",
            "role": role, "active_filter": active, "q": q,
            "role_choices": User.ROLE_CHOICES,
            "querystring": _querystring(request),
        },
    )


@staff_required
def user_detail(request, pk):
    user = get_object_or_404(User, pk=pk)
    # Relations affichées uniquement lorsqu'elles existent réellement pour
    # ce modèle (voir related_name de chaque FK) — jamais une relation
    # Agent<->Property distincte du propriétaire (elle n'existe pas dans le
    # modèle actuel : Property.agent EST le propriétaire, agent ou bailleur).
    properties = Property.objects.filter(agent=user).order_by("-created_at")[:20]
    reservations = Reservation.objects.filter(user=user).select_related("property").order_by("-created_at")[:20]
    conversations = Conversation.objects.filter(Q(client=user) | Q(agent=user)).order_by("-created_at")[:20]
    reviews = Review.objects.filter(user=user).select_related("property").order_by("-created_at")[:20]
    notifications = Notification.objects.filter(recipient=user).order_by("-created_at")[:20]
    agent_profile = AgentProfile.objects.filter(user=user).first()

    return render(
        request,
        "dashboard/user_detail.html",
        {
            "obj": user, "active": "users",
            "properties": properties, "reservations": reservations,
            "conversations": conversations, "reviews": reviews,
            "notifications": notifications, "agent_profile": agent_profile,
        },
    )


@staff_required
def properties_list(request):
    qs = Property.objects.select_related("agent").all()
    transaction_type = request.GET.get("transaction_type", "")
    status = request.GET.get("status", "")
    owner_id = request.GET.get("owner", "")
    q = request.GET.get("q", "")
    if transaction_type:
        qs = qs.filter(transaction_type=transaction_type)
    if status:
        qs = qs.filter(status=status)
    if owner_id:
        qs = qs.filter(agent_id=owner_id)
    if q:
        qs = qs.filter(
            Q(title__icontains=q) | Q(city__icontains=q) | Q(commune__icontains=q)
            | Q(district__icontains=q) | Q(agent__phone__icontains=q)
            | Q(agent__first_name__icontains=q) | Q(agent__last_name__icontains=q)
        )
    page = _paginate(request, qs)
    return render(
        request,
        "dashboard/properties_list.html",
        {
            "page_obj": page, "active": "properties",
            "transaction_type": transaction_type, "status": status, "q": q,
            "transaction_choices": Property.TRANSACTION_CHOICES,
            "status_choices": Property.STATUS_CHOICES,
            "querystring": _querystring(request),
        },
    )


@staff_required
def property_detail(request, pk):
    obj = get_object_or_404(Property.objects.select_related("agent"), pk=pk)
    reservations = Reservation.objects.filter(property=obj).select_related("user").order_by("-created_at")
    reviews = Review.objects.filter(property=obj).select_related("user").order_by("-created_at")
    return render(
        request,
        "dashboard/property_detail.html",
        {"obj": obj, "active": "properties", "reservations": reservations, "reviews": reviews},
    )


@staff_required
def reservations_list(request):
    qs = Reservation.objects.select_related("property", "property__agent", "user").all()
    status = request.GET.get("status", "")
    q = request.GET.get("q", "")
    if status:
        qs = qs.filter(status=status)
    if q:
        qs = qs.filter(
            Q(property__title__icontains=q) | Q(user__phone__icontains=q)
            | Q(user__first_name__icontains=q) | Q(user__last_name__icontains=q)
        )
    page = _paginate(request, qs)
    return render(
        request,
        "dashboard/reservations_list.html",
        {
            "page_obj": page, "active": "reservations", "status": status, "q": q,
            "status_choices": Reservation.STATUS_CHOICES, "querystring": _querystring(request),
        },
    )


@staff_required
def conversations_list(request):
    # "Dernier message" affiché sans N+1 : une seule sous-requête corrélée
    # plutôt qu'un .last() par ligne (voir mission section 20 — éviter les
    # requêtes N+1, utiliser annotate/Subquery).
    last_message_qs = Message.objects.filter(conversation=OuterRef("pk")).order_by("-created_at")
    qs = (
        Conversation.objects.select_related("client", "agent", "property")
        .annotate(
            messages_count=Count("messages"),
            last_message_content=Subquery(last_message_qs.values("content")[:1]),
            last_message_attachment_type=Subquery(last_message_qs.values("attachment_type")[:1]),
        )
        .order_by("-created_at")
    )
    q = request.GET.get("q", "")
    if q:
        qs = qs.filter(
            Q(client__phone__icontains=q) | Q(client__first_name__icontains=q)
            | Q(agent__phone__icontains=q) | Q(agent__first_name__icontains=q)
            | Q(property__title__icontains=q)
        )
    page = _paginate(request, qs)
    return render(
        request, "dashboard/conversations_list.html",
        {"page_obj": page, "active": "conversations", "q": q, "querystring": _querystring(request)},
    )


@staff_required
def conversation_detail(request, pk):
    """Consultation admin des messages — accès réservé au staff (voir
    @staff_required), jamais exposé aux utilisateurs normaux via cette
    interface. Lecture seule : aucune fonctionnalité pour publier un message
    au nom d'un utilisateur (usurpation), non demandée et non implémentée."""
    obj = get_object_or_404(Conversation.objects.select_related("client", "agent", "property"), pk=pk)
    messages = Message.objects.filter(conversation=obj).select_related("sender", "receiver").order_by("created_at")
    return render(request, "dashboard/conversation_detail.html", {"obj": obj, "messages": messages, "active": "conversations"})


@staff_required
def notifications_list(request):
    qs = Notification.objects.select_related("recipient").all()
    notif_type = request.GET.get("type", "")
    read = request.GET.get("read", "")
    q = request.GET.get("q", "")
    if notif_type:
        qs = qs.filter(type=notif_type)
    if read == "1":
        qs = qs.filter(is_read=True)
    elif read == "0":
        qs = qs.filter(is_read=False)
    if q:
        qs = qs.filter(
            Q(recipient__phone__icontains=q) | Q(title__icontains=q) | Q(body__icontains=q)
        )
    page = _paginate(request, qs)
    return render(
        request,
        "dashboard/notifications_list.html",
        {
            "page_obj": page, "active": "notifications", "notif_type": notif_type, "read": read, "q": q,
            "type_choices": Notification.TYPE_CHOICES, "querystring": _querystring(request),
        },
    )


@staff_required
def reviews_list(request):
    qs = Review.objects.select_related("user", "property", "property__agent").all()
    rating = request.GET.get("rating", "")
    q = request.GET.get("q", "")
    if rating:
        qs = qs.filter(rating=rating)
    if q:
        qs = qs.filter(
            Q(property__title__icontains=q) | Q(user__phone__icontains=q)
            | Q(user__first_name__icontains=q) | Q(user__last_name__icontains=q)
        )
    page = _paginate(request, qs)
    return render(
        request, "dashboard/reviews_list.html",
        {"page_obj": page, "active": "reviews", "rating": rating, "q": q, "querystring": _querystring(request)},
    )


@staff_required
def agents_list(request):
    qs = AgentProfile.objects.select_related("user").order_by("-created_at")
    q = request.GET.get("q", "")
    if q:
        qs = qs.filter(
            Q(user__phone__icontains=q) | Q(user__first_name__icontains=q)
            | Q(user__last_name__icontains=q) | Q(agency_name__icontains=q)
        )
    page = _paginate(request, qs)
    return render(
        request, "dashboard/agents_list.html",
        {"page_obj": page, "active": "agents", "q": q, "querystring": _querystring(request)},
    )


@staff_required
def fcm_list(request):
    qs = DeviceToken.objects.select_related("user").all()
    platform = request.GET.get("platform", "")
    active = request.GET.get("active", "")
    if platform:
        qs = qs.filter(platform=platform)
    if active == "1":
        qs = qs.filter(is_active=True)
    elif active == "0":
        qs = qs.filter(is_active=False)
    page = _paginate(request, qs)
    return render(
        request,
        "dashboard/fcm_list.html",
        {
            "page_obj": page, "active": "fcm", "platform": platform, "active_filter": active,
            "platform_choices": DeviceToken.PLATFORM_CHOICES, "querystring": _querystring(request),
        },
    )


@staff_required
def statistics(request):
    """Uniquement des agrégats réels (Count/annotate), jamais de valeur
    fictive. Pas de statistique financière : aucun système de paiement
    n'existe dans le modèle actuel."""
    users_by_role = list(
        User.objects.values("role").annotate(total=Count("id")).order_by("-total")
    )
    properties_by_status = list(
        Property.objects.values("status").annotate(total=Count("id")).order_by("-total")
    )
    properties_by_transaction = list(
        Property.objects.values("transaction_type").annotate(total=Count("id")).order_by("-total")
    )
    reservations_by_status = list(
        Reservation.objects.values("status").annotate(total=Count("id")).order_by("-total")
    )
    reviews_by_rating = list(
        Review.objects.values("rating").annotate(total=Count("id")).order_by("rating")
    )
    top_agents = list(
        Property.objects.values("agent__id", "agent__first_name", "agent__last_name")
        .annotate(total=Count("id"))
        .order_by("-total")[:10]
    )

    def _with_max(rows):
        m = max((r["total"] for r in rows), default=0)
        return {"rows": rows, "max": m}

    return render(
        request,
        "dashboard/statistics.html",
        {
            "active": "statistics",
            "users_by_role": _with_max(users_by_role),
            "properties_by_status": _with_max(properties_by_status),
            "properties_by_transaction": _with_max(properties_by_transaction),
            "reservations_by_status": _with_max(reservations_by_status),
            "reviews_by_rating": _with_max(reviews_by_rating),
            "top_agents": top_agents,
        },
    )
