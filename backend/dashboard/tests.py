from django.contrib.auth import get_user_model
from django.db import connection
from django.test import TestCase
from django.test.utils import CaptureQueriesContext
from django.urls import reverse

from agents.models import AgentProfile
from messaging.models import Conversation, Message
from notifications.models import DeviceToken, Notification
from properties.models import Property
from reservations.models import Reservation
from reviews.models import Review

User = get_user_model()


def _make_user(phone, role, **extra):
    return User.objects.create_user(
        phone=phone, password="secret123", first_name=role.capitalize(), last_name=phone,
        role=role, **extra,
    )


PROTECTED_URL_NAMES = [
    "dashboard:index",
    "dashboard:users_list",
    "dashboard:properties_list",
    "dashboard:reservations_list",
    "dashboard:conversations_list",
    "dashboard:notifications_list",
    "dashboard:reviews_list",
    "dashboard:agents_list",
    "dashboard:pending_activations",
    "dashboard:fcm_list",
    "dashboard:statistics",
]


class DashboardAccessControlTests(TestCase):
    """Section 19 de la mission : chaque vue dashboard doit refuser l'accès
    côté serveur — jamais un simple bouton caché. Testé directement avec le
    client de test Django sur les URLs, pas seulement en lisant le code."""

    @classmethod
    def setUpTestData(cls):
        cls.admin = _make_user("0700000001", User.ROLE_CLIENT, is_staff=True, is_superuser=True)
        cls.staff_only = _make_user("0700000002", User.ROLE_CLIENT, is_staff=True, is_superuser=False)
        cls.client_user = _make_user("0700000003", User.ROLE_CLIENT)
        cls.bailleur_user = _make_user("0700000004", User.ROLE_BAILLEUR)
        cls.agent_user = _make_user("0700000005", User.ROLE_AGENT)

    def test_unauthenticated_redirected_to_login_for_every_protected_url(self):
        for name in PROTECTED_URL_NAMES:
            response = self.client.get(reverse(name))
            self.assertEqual(response.status_code, 302, name)
            self.assertIn(reverse("dashboard:login"), response.url, name)

    def test_client_role_denied_for_every_protected_url(self):
        self.client.force_login(self.client_user)
        for name in PROTECTED_URL_NAMES:
            response = self.client.get(reverse(name))
            self.assertEqual(response.status_code, 302, name)

    def test_bailleur_role_denied_for_every_protected_url(self):
        self.client.force_login(self.bailleur_user)
        for name in PROTECTED_URL_NAMES:
            response = self.client.get(reverse(name))
            self.assertEqual(response.status_code, 302, name)

    def test_agent_role_denied_for_every_protected_url(self):
        self.client.force_login(self.agent_user)
        for name in PROTECTED_URL_NAMES:
            response = self.client.get(reverse(name))
            self.assertEqual(response.status_code, 302, name)

    def test_staff_user_allowed_for_every_protected_url(self):
        self.client.force_login(self.staff_only)
        for name in PROTECTED_URL_NAMES:
            response = self.client.get(reverse(name))
            self.assertEqual(response.status_code, 200, name)

    def test_superuser_allowed_for_every_protected_url(self):
        self.client.force_login(self.admin)
        for name in PROTECTED_URL_NAMES:
            response = self.client.get(reverse(name))
            self.assertEqual(response.status_code, 200, name)

    def test_login_form_accepts_staff_account(self):
        response = self.client.post(
            reverse("dashboard:login"), {"username": "0700000001", "password": "secret123"},
        )
        self.assertEqual(response.status_code, 302)
        self.assertEqual(response.url, reverse("dashboard:index"))
        # La session est bien active ensuite (pas de redirect vers login).
        response2 = self.client.get(reverse("dashboard:index"))
        self.assertEqual(response2.status_code, 200)

    def test_login_form_rejects_non_staff_account_and_leaves_no_session(self):
        """Un compte métier valide (bon téléphone/mot de passe) ne doit
        JAMAIS obtenir de session dashboard exploitable — testé en vérifiant
        qu'après la tentative, l'accès aux pages protégées est toujours
        refusé (pas de session fantôme laissée active)."""
        response = self.client.post(
            reverse("dashboard:login"), {"username": "0700000003", "password": "secret123"},
        )
        self.assertEqual(response.status_code, 200)  # form_invalid, reste sur la page
        response2 = self.client.get(reverse("dashboard:index"))
        self.assertEqual(response2.status_code, 302)

    def test_login_page_does_not_loop_when_non_staff_session_exists(self):
        """Un compte non-staff qui aurait une session active (ex: force_login
        en test, ou ancienne session) visitant /dashboard/login/ doit être
        déconnecté proprement puis voir le formulaire — jamais de boucle de
        redirection infinie."""
        self.client.force_login(self.client_user)
        response = self.client.get(reverse("dashboard:login"))
        self.assertEqual(response.status_code, 200)

    def test_logout_clears_session(self):
        self.client.force_login(self.admin)
        self.client.get(reverse("dashboard:logout"))
        response = self.client.get(reverse("dashboard:index"))
        self.assertEqual(response.status_code, 302)


class DashboardDataAccuracyTests(TestCase):
    """Section 24 de la mission : les chiffres affichés doivent correspondre
    exactement aux QuerySets réels, jamais une valeur statique/fictive."""

    @classmethod
    def setUpTestData(cls):
        cls.admin = _make_user("0700000010", User.ROLE_CLIENT, is_staff=True, is_superuser=True)
        cls.agent = _make_user("0700000011", User.ROLE_AGENT)
        cls.bailleur = _make_user("0700000012", User.ROLE_BAILLEUR)
        cls.client_user = _make_user("0700000013", User.ROLE_CLIENT)
        cls.client_user2 = _make_user("0700000014", User.ROLE_CLIENT)

        cls.prop1 = Property.objects.create(
            title="Appart A", type="logement", category="Studio", transaction_type="location",
            price=100000, commune="Cocody", district="Angre", status="disponible", agent=cls.agent,
        )
        cls.prop2 = Property.objects.create(
            title="Villa B", type="logement", category="Villa", transaction_type="vente",
            price=500000, commune="Yopougon", district="Selmer", status="occupee", agent=cls.bailleur,
        )
        cls.reservation = Reservation.objects.create(
            property=cls.prop1, user=cls.client_user, rent=100000, status="enCours",
        )
        cls.conversation = Conversation.objects.create(client=cls.bailleur, agent=cls.agent, property=cls.prop1)
        cls.message = Message.objects.create(
            conversation=cls.conversation, sender=cls.bailleur, receiver=cls.agent, content="Bonjour",
        )
        cls.notification = Notification.objects.create(
            recipient=cls.agent, type=Notification.TYPE_NEW_MESSAGE, title="Nouveau message", body="Bonjour",
        )
        cls.review = Review.objects.create(property=cls.prop1, user=cls.client_user2, rating=4, comment="Bien")
        cls.agent_profile = AgentProfile.objects.create(user=cls.agent, agency_name="Agence Test")
        cls.device_token = DeviceToken.objects.create(user=cls.agent, token="fake-token-123", platform="android")

    def setUp(self):
        self.client.force_login(self.admin)

    def test_index_stats_match_real_querysets(self):
        response = self.client.get(reverse("dashboard:index"))
        stats = response.context["stats"]
        self.assertEqual(stats["users_total"], User.objects.count())
        self.assertEqual(stats["clients"], User.objects.filter(role=User.ROLE_CLIENT).count())
        self.assertEqual(stats["bailleurs"], User.objects.filter(role=User.ROLE_BAILLEUR).count())
        self.assertEqual(stats["agents"], User.objects.filter(role=User.ROLE_AGENT).count())
        self.assertEqual(stats["properties_total"], Property.objects.count())
        self.assertEqual(stats["properties_disponible"], Property.objects.filter(status="disponible").count())
        self.assertEqual(stats["properties_occupee"], Property.objects.filter(status="occupee").count())
        self.assertEqual(stats["reservations_total"], Reservation.objects.count())
        self.assertEqual(stats["conversations_total"], Conversation.objects.count())
        self.assertEqual(stats["messages_total"], Message.objects.count())
        self.assertEqual(stats["notifications_total"], Notification.objects.count())
        self.assertEqual(stats["reviews_total"], Review.objects.count())

    def test_users_list_shows_created_users(self):
        response = self.client.get(reverse("dashboard:users_list"))
        self.assertContains(response, "0700000011")
        self.assertContains(response, "0700000012")

    def test_users_list_never_exposes_password(self):
        response = self.client.get(reverse("dashboard:users_list"))
        content = response.content.decode()
        self.assertNotIn(self.agent.password, content)

    def test_users_list_role_filter(self):
        response = self.client.get(reverse("dashboard:users_list"), {"role": User.ROLE_AGENT})
        page = response.context["page_obj"]
        self.assertTrue(all(u.role == User.ROLE_AGENT for u in page))

    def test_properties_list_and_filters(self):
        response = self.client.get(reverse("dashboard:properties_list"), {"status": "disponible"})
        page = response.context["page_obj"]
        self.assertTrue(all(p.status == "disponible" for p in page))

    def test_property_detail_shows_real_owner(self):
        response = self.client.get(reverse("dashboard:property_detail", args=[self.prop1.pk]))
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, "0700000011")

    def test_reservation_does_not_force_property_occupied(self):
        """Le dashboard ne doit jamais afficher ou impliquer un comportement
        où une réservation force automatiquement le statut occupée — il
        reflète simplement le statut réel de la propriété en base."""
        self.prop1.refresh_from_db()
        self.assertEqual(self.prop1.status, "disponible")

    def test_reservations_list_shows_owner_column(self):
        response = self.client.get(reverse("dashboard:reservations_list"))
        self.assertContains(response, "Appart A")
        self.assertContains(response, "0700000011")  # propriétaire (agent)

    def test_conversations_list_shows_last_message_without_n_plus_1(self):
        response = self.client.get(reverse("dashboard:conversations_list"))
        self.assertContains(response, "Bonjour")

        # Preuve concrète d'absence de N+1 : le nombre de requêtes générées
        # par la page ne doit pas augmenter avec le nombre de conversations
        # (le "dernier message" est résolu par une sous-requête corrélée
        # unique, pas par un .last() exécuté à chaque ligne).
        with CaptureQueriesContext(connection) as ctx_before:
            self.client.get(reverse("dashboard:conversations_list"))
        queries_with_one_conversation = len(ctx_before.captured_queries)

        other_agent = _make_user("0700000020", User.ROLE_AGENT)
        other_client = _make_user("0700000021", User.ROLE_CLIENT)
        for i in range(5):
            conv = Conversation.objects.create(
                client=other_client, agent=other_agent,
                property=Property.objects.create(
                    title=f"Bien {i}", type="logement", category="Studio", transaction_type="location",
                    price=1000, commune="X", district="Y", agent=other_agent,
                ),
            )
            Message.objects.create(conversation=conv, sender=other_client, receiver=other_agent, content=f"msg {i}")

        with CaptureQueriesContext(connection) as ctx_after:
            self.client.get(reverse("dashboard:conversations_list"))
        queries_with_six_conversations = len(ctx_after.captured_queries)

        self.assertEqual(queries_with_one_conversation, queries_with_six_conversations)

    def test_conversation_detail_shows_messages(self):
        response = self.client.get(reverse("dashboard:conversation_detail", args=[self.conversation.pk]))
        self.assertContains(response, "Bonjour")

    def test_notifications_list_has_no_actor_column(self):
        """Le modèle Notification ne stocke pas d'acteur — vérifie que la
        page l'indique explicitement plutôt que d'inventer la donnée."""
        response = self.client.get(reverse("dashboard:notifications_list"))
        self.assertContains(response, "ne stocke pas d")

    def test_reviews_list_shows_real_owner(self):
        response = self.client.get(reverse("dashboard:reviews_list"))
        self.assertContains(response, "Appart A")

    def test_agents_list_shows_agent_profile(self):
        response = self.client.get(reverse("dashboard:agents_list"))
        self.assertContains(response, "Agence Test")

    def test_fcm_list_truncates_token(self):
        response = self.client.get(reverse("dashboard:fcm_list"))
        content = response.content.decode()
        self.assertNotIn("fake-token-123", content)  # jamais le token complet
        self.assertIn("fake-token", content)  # préfixe tronqué visible pour identifier l'entrée

    def test_statistics_page_renders_real_aggregates(self):
        response = self.client.get(reverse("dashboard:statistics"))
        self.assertEqual(response.status_code, 200)
        role_totals = {row["role"]: row["total"] for row in response.context["users_by_role"]["rows"]}
        self.assertEqual(role_totals.get(User.ROLE_AGENT), User.objects.filter(role=User.ROLE_AGENT).count())

    def test_pending_activations_page_lists_unapproved_users(self):
        unapproved = _make_user("0700000088", User.ROLE_BAILLEUR, is_approved=False, activation_requested=True, whatsapp="0700000088")
        response = self.client.get(reverse("dashboard:pending_activations"))
        self.assertEqual(response.status_code, 200)
        self.assertContains(response, unapproved.phone)

    def test_activate_user_view_activates_account(self):
        unapproved = _make_user("0700000089", User.ROLE_BAILLEUR, is_approved=False, whatsapp="0700000089")
        response = self.client.post(reverse("dashboard:activate_user", args=[unapproved.pk]))
        self.assertEqual(response.status_code, 302)
        unapproved.refresh_from_db()
        self.assertTrue(unapproved.is_approved)

    def test_delete_user_view_deletes_user_and_cascades_safely(self):
        target_agent = _make_user("0700000090", User.ROLE_AGENT)
        client_user = _make_user("0700000091", User.ROLE_CLIENT)
        prop = Property.objects.create(
            title="Bien à supprimer", category="Studio", type="logement",
            transaction_type="location", price=100000, commune="X", district="Y",
            agent=target_agent,
        )
        res = Reservation.objects.create(property=prop, user=client_user, rent=100000)

        # GET affiche la page de confirmation
        get_response = self.client.get(reverse("dashboard:delete_user", args=[target_agent.pk]))
        self.assertEqual(get_response.status_code, 200)
        self.assertContains(get_response, "Supprimer définitivement")

        # POST effectue la suppression en cascade sans ProtectedError
        post_response = self.client.post(reverse("dashboard:delete_user", args=[target_agent.pk]))
        self.assertEqual(post_response.status_code, 302)
        self.assertFalse(User.objects.filter(pk=target_agent.pk).exists())
        self.assertFalse(Property.objects.filter(pk=prop.pk).exists())
        self.assertFalse(Reservation.objects.filter(pk=res.pk).exists())

    def test_cannot_delete_logged_in_admin(self):
        response = self.client.post(reverse("dashboard:delete_user", args=[self.admin.pk]))
        self.assertEqual(response.status_code, 302)
        self.assertTrue(User.objects.filter(pk=self.admin.pk).exists())

    def test_toggle_certificate_for_agent(self):
        target_agent = _make_user("0700000092", User.ROLE_AGENT)
        profile = AgentProfile.objects.create(user=target_agent, agency_name="Agence Immo")
        self.assertFalse(target_agent.is_verified)
        self.assertFalse(profile.is_verified)

        # Activer le badge
        response = self.client.post(reverse("dashboard:toggle_certificate", args=[target_agent.pk]))
        self.assertEqual(response.status_code, 302)
        target_agent.refresh_from_db()
        profile.refresh_from_db()
        self.assertTrue(target_agent.is_verified)
        self.assertTrue(profile.is_verified)

        # Désactiver le badge
        response2 = self.client.post(reverse("dashboard:toggle_certificate", args=[target_agent.pk]))
        self.assertEqual(response2.status_code, 302)
        target_agent.refresh_from_db()
        profile.refresh_from_db()
        self.assertFalse(target_agent.is_verified)
        self.assertFalse(profile.is_verified)

    def test_toggle_certificate_for_bailleur(self):
        target_bailleur = _make_user("0700000093", User.ROLE_BAILLEUR)
        self.assertFalse(target_bailleur.is_verified)

        # Activer le badge
        response = self.client.post(reverse("dashboard:toggle_certificate", args=[target_bailleur.pk]))
        self.assertEqual(response.status_code, 302)
        target_bailleur.refresh_from_db()
        self.assertTrue(target_bailleur.is_verified)

    def test_toggle_certificate_forbidden_for_client(self):
        target_client = _make_user("0700000094", User.ROLE_CLIENT)
        response = self.client.post(reverse("dashboard:toggle_certificate", args=[target_client.pk]))
        self.assertEqual(response.status_code, 302)
        target_client.refresh_from_db()
        self.assertFalse(target_client.is_verified)

