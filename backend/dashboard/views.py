"""Dashboard administrateur personnalisé — vues Django classiques
(templates + sessions), jamais de JWT ici. Chaque vue est protégée
individuellement par @staff_required (voir dashboard/decorators.py),
jamais uniquement par un lien caché côté template.

Aucune statistique n'est codée en dur : chaque nombre affiché correspond
à un QuerySet réellement exécuté (voir dashboard/tests.py qui compare les
chiffres affichés à User.objects.count() etc.)."""

from django.contrib import messages
from django.contrib.auth import views as auth_views
from django.core.paginator import Paginator
from django.db import transaction
from django.db.models import Count, OuterRef, Q, Subquery, Sum
from django.shortcuts import get_object_or_404, redirect, render
from django.urls import reverse_lazy
from django.utils import timezone

from accounts.models import User
from agents.models import AgentProfile
from messaging.models import Conversation, Message
from notifications.models import DeviceToken, Notification
from payments.models import Subscription
from properties.models import Property
from reservations.models import Reservation
from reviews.models import Review

from .decorators import staff_required
from .models import AppConfiguration

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
        "pending_activations": User.objects.filter(role__in=[User.ROLE_BAILLEUR, User.ROLE_AGENT], is_approved=False).count(),
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
        "subscriptions_total": Subscription.objects.count(),
        "subscriptions_active": Subscription.objects.filter(status=Subscription.STATUS_ACTIVE, expires_at__gt=timezone.now()).count(),
    }

    # Activité récente : fusion d'événements réellement horodatés
    # (created_at existe sur chacun de ces modèles), triés ensemble. Aucun
    # événement fabriqué — uniquement ce que created_at atteste vraiment.
    events = []
    for u in User.objects.filter(role__in=[User.ROLE_BAILLEUR, User.ROLE_AGENT], activation_requested=True, is_approved=False).order_by("-activation_requested_at")[:5]:
        if u.activation_requested_at:
            events.append({"type": "Demande d'activation", "label": f"{u.first_name} {u.last_name} ({u.get_role_display()}) — WhatsApp: {u.whatsapp or u.phone}", "when": u.activation_requested_at, "role": u.role})
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
    subscriptions = user.subscriptions.order_by("-created_at")[:20]

    return render(
        request,
        "dashboard/user_detail.html",
        {
            "obj": user, "active": "users",
            "properties": properties, "reservations": reservations,
            "conversations": conversations, "reviews": reviews,
            "notifications": notifications, "agent_profile": agent_profile,
            "subscriptions": subscriptions,
        },
    )


@staff_required
def delete_user(request, pk):
    """Supprime n'importe quel utilisateur et nettoie toutes ses dépendances protégées
    (propriétés, réservations liées, fichiers vidéo, profil, etc.) dans une transaction atomique."""
    user = get_object_or_404(User, pk=pk)
    if user == request.user:
        messages.error(request, "Action refusée : vous ne pouvez pas supprimer votre propre compte administrateur actuellement connecté.")
        return redirect("dashboard:user_detail", pk=pk)

    if request.method == "POST":
        user_name = f"{user.first_name} {user.last_name} ({user.phone})"
        with transaction.atomic():
            # 1. Supprimer les propriétés et leurs réservations protégées
            user_properties = Property.objects.filter(agent=user)
            for prop in user_properties:
                prop.reservations.all().delete()
                if prop.video:
                    prop.video.delete(save=False)
                prop.delete()

            # 2. Supprimer les réservations effectuées par l'utilisateur
            Reservation.objects.filter(user=user).delete()

            # 3. Supprimer le profil agent si existant
            AgentProfile.objects.filter(user=user).delete()

            # 4. Supprimer l'utilisateur définitivement
            user.delete()

        messages.success(request, f"L'utilisateur {user_name} et toutes ses données associées ont été supprimés avec succès.")
        next_url = request.POST.get("next") or request.GET.get("next") or ""
        if next_url and next_url.startswith("/dashboard/"):
            return redirect(next_url)
        return redirect("dashboard:users_list")

    return render(
        request,
        "dashboard/user_confirm_delete.html",
        {
            "obj": user,
            "active": "users",
            "next_url": request.GET.get("next", ""),
            "properties_count": Property.objects.filter(agent=user).count(),
            "reservations_count": Reservation.objects.filter(user=user).count(),
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
    audience_counts = {
        "all": User.objects.filter(is_active=True).count(),
        "clients": User.objects.filter(is_active=True, role=User.ROLE_CLIENT).count(),
        "bailleurs": User.objects.filter(is_active=True, role=User.ROLE_BAILLEUR).count(),
        "agents": User.objects.filter(is_active=True, role=User.ROLE_AGENT).count(),
        "verified": User.objects.filter(is_active=True, is_verified=True).count(),
        "active_devices": DeviceToken.objects.filter(is_active=True).count(),
    }
    return render(
        request,
        "dashboard/notifications_list.html",
        {
            "page_obj": page,
            "active": "notifications",
            "notif_type": notif_type,
            "read": read,
            "q": q,
            "type_choices": Notification.TYPE_CHOICES,
            "audience_counts": audience_counts,
            "querystring": _querystring(request),
        },
    )


@staff_required
def broadcast_notification(request):
    """POST /dashboard/notifications/broadcast/
    Permet à l'administrateur d'envoyer un message groupé (notification in-app + Push FCM réel sur téléphone)
    à tous les utilisateurs ou à un segment ciblé (Clients, Bailleurs, Agents, Certifiés)."""
    if request.method != "POST":
        return redirect("dashboard:notifications_list")

    title = (request.POST.get("title") or "").strip()
    body = (request.POST.get("body") or "").strip()
    target = (request.POST.get("target") or "all").strip()

    if not title or not body:
        messages.error(request, "Veuillez renseigner à la fois le titre et le message de la notification.")
        return redirect("dashboard:notifications_list")

    qs = User.objects.filter(is_active=True)
    target_labels = {
        "all": "tous les utilisateurs actifs",
        "client": "tous les clients",
        "bailleur": "tous les bailleurs",
        "agent": "tous les agents immobiliers",
        "pro": "tous les bailleurs et agents",
        "verified": "tous les comptes certifiés",
    }
    if target == "client":
        qs = qs.filter(role=User.ROLE_CLIENT)
    elif target == "bailleur":
        qs = qs.filter(role=User.ROLE_BAILLEUR)
    elif target == "agent":
        qs = qs.filter(role=User.ROLE_AGENT)
    elif target == "pro":
        qs = qs.filter(role__in=[User.ROLE_BAILLEUR, User.ROLE_AGENT])
    elif target == "verified":
        qs = qs.filter(is_verified=True)

    from notifications.services import NotificationService

    result = NotificationService.broadcast(
        recipients_qs=qs,
        title=title[:200],
        body=body,
        data={"target": target},
    )
    label = target_labels.get(target, "les utilisateurs sélectionnés")
    messages.success(
        request,
        f"Diffusion envoyée avec succès à {result['users_count']} utilisateur(s) ({label}) "
        f"et transmise en temps réel vers {result['devices_count']} téléphone(s) enregistré(s).",
    )
    return redirect("dashboard:notifications_list")


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
    qs = (
        User.objects.filter(role__in=[User.ROLE_AGENT, User.ROLE_BAILLEUR])
        .select_related("agent_profile")
        .annotate(properties_count=Count("properties", distinct=True))
        .order_by("-date_joined")
    )
    role = request.GET.get("role", "")
    q = request.GET.get("q", "")
    if role in (User.ROLE_AGENT, User.ROLE_BAILLEUR):
        qs = qs.filter(role=role)
    if q:
        qs = qs.filter(
            Q(phone__icontains=q)
            | Q(whatsapp__icontains=q)
            | Q(first_name__icontains=q)
            | Q(last_name__icontains=q)
            | Q(agent_profile__agency_name__icontains=q)
        )
    page = _paginate(request, qs)
    return render(
        request,
        "dashboard/agents_list.html",
        {
            "page_obj": page,
            "active": "agents",
            "q": q,
            "role": role,
            "role_choices": [
                (User.ROLE_BAILLEUR, "Bailleurs"),
                (User.ROLE_AGENT, "Agents immobiliers"),
            ],
            "querystring": _querystring(request),
        },
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


@staff_required
def pending_activations(request):
    """Rubrique 'Comptes à activer' pour les agents et bailleurs en attente d'activation."""
    qs = User.objects.filter(
        role__in=[User.ROLE_BAILLEUR, User.ROLE_AGENT],
        is_approved=False,
    ).order_by("-activation_requested", "-date_joined")
    role = request.GET.get("role", "")
    q = request.GET.get("q", "")
    if role:
        qs = qs.filter(role=role)
    if q:
        qs = qs.filter(
            Q(phone__icontains=q) | Q(first_name__icontains=q)
            | Q(last_name__icontains=q) | Q(whatsapp__icontains=q)
        )
    page = _paginate(request, qs)
    return render(
        request,
        "dashboard/pending_activations.html",
        {
            "page_obj": page,
            "active": "pending_activations",
            "role": role,
            "q": q,
            "role_choices": [
                (User.ROLE_BAILLEUR, "Bailleur"),
                (User.ROLE_AGENT, "Agent immobilier"),
            ],
            "querystring": _querystring(request),
        },
    )


@staff_required
def activate_user(request, pk):
    """Active le compte d'un agent ou bailleur depuis le dashboard."""
    user = get_object_or_404(User, pk=pk)
    if request.method == "POST":
        user.is_approved = True
        user.is_active = True
        user.save(update_fields=["is_approved", "is_active"])
        if user.role == User.ROLE_AGENT:
            profile = AgentProfile.objects.filter(user=user).first()
            if profile:
                profile.is_verified = True
                profile.save(update_fields=["is_verified"])
        from django.contrib import messages
        messages.success(
            request,
            f"Le compte de {user.first_name} {user.last_name} ({user.get_role_display()}) a été activé avec succès !",
        )
        referer = request.META.get("HTTP_REFERER", "")
        if "users/" in referer:
            return redirect("dashboard:user_detail", pk=user.pk)
    return redirect("dashboard:pending_activations")


@staff_required
def toggle_certificate(request, pk):
    """Active ou désactive le badge Certificat pour un agent ou un bailleur.
    Règle métier stricte : seuls les agents et bailleurs peuvent avoir un badge de certification."""
    user = get_object_or_404(User, pk=pk)
    if user.role not in (User.ROLE_AGENT, User.ROLE_BAILLEUR):
        messages.error(
            request,
            "Action refusée : seuls les agents et les bailleurs peuvent obtenir un badge de certification.",
        )
        return redirect("dashboard:user_detail", pk=pk)

    if request.method == "POST":
        new_status = not user.is_verified
        user.is_verified = new_status
        user.save(update_fields=["is_verified"])

        if user.role == User.ROLE_AGENT:
            profile, _ = AgentProfile.objects.get_or_create(user=user)
            profile.is_verified = new_status
            profile.certification_status = (
                AgentProfile.CERTIFICATION_APPROVED
                if new_status
                else AgentProfile.CERTIFICATION_NOT_REQUESTED
            )
            profile.save(update_fields=["is_verified", "certification_status"])

        if not new_status:
            # Révoquer et annuler immédiatement tout abonnement actif de l'utilisateur
            # pour garantir que le badge ne subsiste pas et que l'action admin est immédiatement effective
            for sub in user.subscriptions.filter(status=Subscription.STATUS_ACTIVE):
                sub.cancel_and_revoke()

        action_label = "activé" if new_status else "retiré"
        messages.success(
            request,
            f"Badge de certification {action_label} avec succès pour {user.first_name} {user.last_name} ({user.get_role_display()}) !",
        )

    referer = request.META.get("HTTP_REFERER", "")
    if "users/" in referer:
        return redirect("dashboard:user_detail", pk=pk)
    if "agents" in referer:
        return redirect("dashboard:agents_list")
    return redirect("dashboard:user_detail", pk=pk)


@staff_required
def app_settings_view(request):
    """GET / POST /dashboard/app-settings/
    Pilotage en temps réel de l'application mobile (Solution 2 : Server-Driven Config + Solution 1 : Shorebird OTA)."""
    cfg = AppConfiguration.get_solo()
    if request.method == "POST":
        cfg.app_version = (request.POST.get("app_version") or cfg.app_version).strip()
        cfg.min_supported_version = (request.POST.get("min_supported_version") or cfg.min_supported_version).strip()
        cfg.ota_auto_update_enabled = request.POST.get("ota_auto_update_enabled") == "1"
        cfg.maintenance_mode = request.POST.get("maintenance_mode") == "1"
        cfg.maintenance_message = (request.POST.get("maintenance_message") or "").strip()
        cfg.announcement_enabled = request.POST.get("announcement_enabled") == "1"
        cfg.announcement_title = (request.POST.get("announcement_title") or "").strip()[:120]
        cfg.announcement_body = (request.POST.get("announcement_body") or "").strip()
        cfg.support_whatsapp = (request.POST.get("support_whatsapp") or "").strip()[:30]

        try:
            client_price = int(request.POST.get("client_subscription_price") or cfg.client_subscription_price)
            if client_price >= 100:
                cfg.client_subscription_price = client_price
        except ValueError:
            pass

        try:
            pro_price = int(request.POST.get("pro_subscription_price") or cfg.pro_subscription_price)
            if pro_price >= 100:
                cfg.pro_subscription_price = pro_price
        except ValueError:
            pass

        selected_methods = request.POST.getlist("payment_methods")
        if selected_methods:
            cfg.enabled_payment_methods = ",".join(selected_methods)

        cfg.save()
        messages.success(
            request,
            "La configuration dynamique de l'application a été mise à jour ! Les changements sont immédiatement actifs sur tous les téléphones.",
        )
        return redirect("dashboard:app_settings")

    enabled_methods = [m.strip() for m in cfg.enabled_payment_methods.split(",") if m.strip()]
    return render(
        request,
        "dashboard/app_settings.html",
        {
            "cfg": cfg,
            "enabled_methods": enabled_methods,
            "active": "app_settings",
        },
    )


def public_app_config_api(request):
    """GET /api/config/app-settings/
    Endpoint public ultra-léger interrogé silencieusement par l'application Flutter
    au démarrage et au retour au premier plan pour mettre à jour l'interface, les tarifs,
    la bannière d'annonce et le contrôle OTA sans passer par le Play Store."""
    from django.http import JsonResponse

    cfg = AppConfiguration.get_solo()
    methods = [m.strip() for m in cfg.enabled_payment_methods.split(",") if m.strip()]
    return JsonResponse(
        {
            "app_version": cfg.app_version,
            "min_supported_version": cfg.min_supported_version,
            "ota_auto_update_enabled": cfg.ota_auto_update_enabled,
            "maintenance_mode": cfg.maintenance_mode,
            "maintenance_message": cfg.maintenance_message,
            "announcement": {
                "enabled": cfg.announcement_enabled,
                "title": cfg.announcement_title,
                "body": cfg.announcement_body,
            },
            "pricing": {
                "client_fcfa": cfg.client_subscription_price,
                "pro_fcfa": cfg.pro_subscription_price,
            },
            "enabled_payment_methods": methods,
            "support_whatsapp": cfg.support_whatsapp,
            "updated_at": cfg.updated_at.isoformat() if cfg.updated_at else None,
        }
    )


@staff_required
def subscriptions_list(request):
    """GET /dashboard/subscriptions/
    Gestion complète et suivi des abonnements clients et professionnels."""
    now = timezone.now()
    qs = Subscription.objects.select_related("user").order_by("-created_at")
    status = request.GET.get("status", "").strip()
    plan = request.GET.get("plan", "").strip()
    q = request.GET.get("q", "").strip()

    if status:
        if status == "active":
            qs = qs.filter(status=Subscription.STATUS_ACTIVE, expires_at__gt=now)
        elif status == "expired":
            qs = qs.filter(
                Q(status=Subscription.STATUS_EXPIRED)
                | Q(status=Subscription.STATUS_ACTIVE, expires_at__lte=now)
            )
        else:
            qs = qs.filter(status=status)
    if plan:
        qs = qs.filter(plan=plan)
    if q:
        qs = qs.filter(
            Q(reference__icontains=q)
            | Q(user__phone__icontains=q)
            | Q(user__first_name__icontains=q)
            | Q(user__last_name__icontains=q)
        )

    stats = {
        "total": Subscription.objects.count(),
        "active": Subscription.objects.filter(
            status=Subscription.STATUS_ACTIVE, expires_at__gt=now
        ).count(),
        "expired": Subscription.objects.filter(
            Q(status=Subscription.STATUS_EXPIRED)
            | Q(status=Subscription.STATUS_ACTIVE, expires_at__lte=now)
        ).count(),
        "cancelled": Subscription.objects.filter(
            status=Subscription.STATUS_CANCELLED
        ).count(),
        "pending": Subscription.objects.filter(
            status=Subscription.STATUS_PENDING
        ).count(),
        "total_revenue": Subscription.objects.filter(
            status__in=[Subscription.STATUS_ACTIVE, Subscription.STATUS_EXPIRED]
        ).aggregate(total=Sum("amount"))["total"]
        or 0,
    }

    page = _paginate(request, qs)
    return render(
        request,
        "dashboard/subscriptions_list.html",
        {
            "page_obj": page,
            "stats": stats,
            "status": status,
            "plan": plan,
            "q": q,
            "active": "subscriptions",
        },
    )


@staff_required
def cancel_subscription(request, pk):
    """POST /dashboard/subscriptions/<pk>/cancel/
    Annule immédiatement un abonnement et révoque le badge certifié associé."""
    sub = get_object_or_404(Subscription, pk=pk)
    if request.method == "POST":
        sub.cancel_and_revoke()
        messages.success(
            request,
            f"L'abonnement {sub.reference} ({sub.get_plan_display()}) de {sub.user} a été annulé avec succès et le badge a été révoqué.",
        )
    referer = request.META.get("HTTP_REFERER", "")
    if "users/" in referer:
        return redirect("dashboard:user_detail", pk=sub.user.pk)
    return redirect("dashboard:subscriptions_list")




