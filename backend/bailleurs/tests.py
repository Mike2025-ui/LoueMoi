from django.contrib.auth import get_user_model
from rest_framework import status
from rest_framework.test import APITestCase

from properties.models import Property

User = get_user_model()


def _make_bailleur(phone):
    return User.objects.create_user(
        phone=phone, password="secret123", first_name="Bailleur", last_name=phone,
        role=User.ROLE_BAILLEUR,
    )


def _make_agent(phone):
    return User.objects.create_user(
        phone=phone, password="secret123", first_name="Agent", last_name=phone,
        role=User.ROLE_AGENT,
    )


def _make_client(phone):
    return User.objects.create_user(
        phone=phone, password="secret123", first_name="Client", last_name=phone,
        role=User.ROLE_CLIENT,
    )


def _make_property(agent, title="Bien bailleur"):
    return Property.objects.create(
        title=title, category="Studio", type="logement", transaction_type="location",
        price=100000, commune="Cocody", district="Vallon", agent=agent,
    )


class BailleurDashboardTests(APITestCase):
    """Test 15 : GET /api/bailleur/dashboard/ — chiffres réels, calculés
    côté Django, jamais codés en dur."""

    def test_dashboard_reflects_real_data(self):
        bailleur = _make_bailleur("+2250711114001")
        _make_property(bailleur, "Bien 1")
        _make_property(bailleur, "Bien 2")

        self.client.force_authenticate(user=bailleur)
        response = self.client.get("/api/bailleur/dashboard/")

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["properties_count"], 2)
        self.assertEqual(response.data["available_count"], 2)

    def test_client_cannot_access_bailleur_dashboard(self):
        client_user = _make_client("+2250711114002")
        self.client.force_authenticate(user=client_user)
        response = self.client.get("/api/bailleur/dashboard/")
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_agent_cannot_access_bailleur_dashboard(self):
        # Rôles strictement indépendants : un agent n'a pas accès au
        # dashboard bailleur (ni l'inverse).
        agent = _make_agent("+2250711114003")
        self.client.force_authenticate(user=agent)
        response = self.client.get("/api/bailleur/dashboard/")
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)


class BailleurPropertiesListTests(APITestCase):
    """Test 16 : GET /api/bailleur/properties/ ne renvoie que les biens du
    bailleur connecté — jamais ceux d'un autre bailleur ni d'un agent."""

    def setUp(self):
        self.bailleur_a = _make_bailleur("+2250711114010")
        self.bailleur_b = _make_bailleur("+2250711114011")
        self.agent = _make_agent("+2250711114012")
        self.property_a = _make_property(self.bailleur_a, "Bien de A")
        self.property_b = _make_property(self.bailleur_b, "Bien de B")
        self.property_agent = _make_property(self.agent, "Bien de l'agent")

    def test_returns_only_own_properties(self):
        self.client.force_authenticate(user=self.bailleur_a)
        response = self.client.get("/api/bailleur/properties/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        titles = [p["title"] for p in response.data["results"]]
        self.assertIn("Bien de A", titles)
        self.assertNotIn("Bien de B", titles)
        self.assertNotIn("Bien de l'agent", titles)

    def test_agent_cannot_access_bailleur_properties_endpoint(self):
        self.client.force_authenticate(user=self.agent)
        response = self.client.get("/api/bailleur/properties/")
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)


class BailleurSearchTests(APITestCase):
    """GET /api/bailleurs/ — décision métier "Recherche propriétaire" (un
    agent peut chercher un bailleur, voir son profil public et ses annonces
    publiques, éventuellement le contacter — jamais de transfert de
    propriété). Symétrique de agents.tests pour AgentSearchView."""

    def setUp(self):
        self.bailleur = _make_bailleur("+2250711114020")
        self.bailleur.first_name = "Awa"
        self.bailleur.last_name = "Kone"
        self.bailleur.save(update_fields=["first_name", "last_name"])
        self.agent = _make_agent("+2250711114021")
        self.client_user = _make_client("+2250711114022")

    def test_search_is_public_even_for_anonymous_users(self):
        response = self.client.get("/api/bailleurs/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        names = [f"{b['first_name']} {b['last_name']}" for b in response.data["results"]]
        self.assertIn("Awa Kone", names)

    def test_only_bailleurs_are_returned_never_agents_or_clients(self):
        response = self.client.get("/api/bailleurs/")
        ids = [b["id"] for b in response.data["results"]]
        self.assertIn(self.bailleur.id, ids)
        self.assertNotIn(self.agent.id, ids)
        self.assertNotIn(self.client_user.id, ids)

    def test_search_filters_by_name(self):
        response = self.client.get("/api/bailleurs/?search=Kone")
        ids = [b["id"] for b in response.data["results"]]
        self.assertEqual(ids, [self.bailleur.id])

        no_match = self.client.get("/api/bailleurs/?search=Zzzz")
        self.assertEqual(no_match.data["results"], [])

    def test_response_never_exposes_password_or_tokens(self):
        response = self.client.get("/api/bailleurs/")
        result = response.data["results"][0]
        self.assertNotIn("password", result)
        self.assertNotIn("token", result)

    def test_agent_can_view_a_bailleurs_public_listings_via_property_filter(self):
        """"voir ses annonces publiques" est servi par le filtre existant
        GET /api/properties/?agent=<id>, pas un nouvel endpoint — hérite
        donc automatiquement des mêmes règles de visibilité publique."""
        _make_property(self.bailleur, "Studio du bailleur")
        other_bailleur = _make_bailleur("+2250711114023")
        _make_property(other_bailleur, "Studio d'un autre bailleur")

        self.client.force_authenticate(user=self.agent)
        response = self.client.get(f"/api/properties/?agent={self.bailleur.id}")
        titles = [p["title"] for p in response.data["results"]]
        self.assertIn("Studio du bailleur", titles)
        self.assertNotIn("Studio d'un autre bailleur", titles)
