from django.contrib.auth import get_user_model
from rest_framework import status
from rest_framework.test import APITestCase

from .models import Property

User = get_user_model()


def _make_agent(phone):
    return User.objects.create_user(
        phone=phone, password="secret123", first_name="Agent", last_name=phone,
        role=User.ROLE_AGENT,
    )


def _make_client_user(phone):
    return User.objects.create_user(
        phone=phone, password="secret123", first_name="Client", last_name=phone,
        role=User.ROLE_CLIENT,
    )


def _make_property(agent, title="Bien test"):
    return Property.objects.create(
        title=title,
        category="Studio",
        type="logement",
        transaction_type="location",
        price=100000,
        commune="Cocody",
        district="Vallon",
        agent=agent,
    )


class PropertyPermissionTests(APITestCase):
    """Tests 3 à 9 (voir cahier des charges section 30)."""

    def setUp(self):
        self.client_user = _make_client_user("+2250711111101")
        self.agent_a = _make_agent("+2250711111102")
        self.agent_b = _make_agent("+2250711111103")
        self.property_a = _make_property(self.agent_a, "Bien de A")

    def _new_property_payload(self, title="Nouveau bien"):
        return {
            "title": title,
            "category": "Studio",
            "type": "logement",
            "transaction_type": "location",
            "price": 1000,
            "commune": "X",
            "district": "Y",
        }

    def test_client_cannot_create_property(self):
        self.client.force_authenticate(user=self.client_user)
        response = self.client.post("/api/properties/", self._new_property_payload(), format="json")
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_agent_can_create_property(self):
        self.client.force_authenticate(user=self.agent_b)
        response = self.client.post("/api/properties/", self._new_property_payload(), format="json")
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        # L'annonce est toujours assignée à l'agent connecté, jamais choisie
        # par le client.
        self.assertEqual(response.data["agent"]["id"], self.agent_b.id)

    def test_agent_can_see_public_properties(self):
        self.client.force_authenticate(user=self.agent_b)
        response = self.client.get("/api/properties/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertGreaterEqual(response.data["count"], 1)

    def test_agent_a_can_view_agent_b_property(self):
        property_b = _make_property(self.agent_b, "Bien de B")
        self.client.force_authenticate(user=self.agent_a)
        response = self.client.get(f"/api/properties/{property_b.id}/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)

    def test_agent_a_cannot_modify_agent_b_property(self):
        property_b = _make_property(self.agent_b, "Bien de B")
        self.client.force_authenticate(user=self.agent_a)
        response = self.client.patch(
            f"/api/properties/{property_b.id}/", {"title": "Hack"}, format="json"
        )
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_agent_a_cannot_delete_agent_b_property(self):
        property_b = _make_property(self.agent_b, "Bien de B")
        self.client.force_authenticate(user=self.agent_a)
        response = self.client.delete(f"/api/properties/{property_b.id}/")
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
        self.assertTrue(Property.objects.filter(pk=property_b.pk).exists())

    def test_agent_can_modify_own_property(self):
        self.client.force_authenticate(user=self.agent_a)
        response = self.client.patch(
            f"/api/properties/{self.property_a.id}/", {"title": "Modifie"}, format="json"
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.property_a.refresh_from_db()
        self.assertEqual(self.property_a.title, "Modifie")


class MyPropertiesEndpointTests(APITestCase):
    """/api/agent/properties/ ne doit renvoyer que les biens de l'agent
    connecté — jamais les biens d'un autre agent, jamais accessible à un
    client (couvre la section 20 du cahier des charges)."""

    def setUp(self):
        self.agent_a = _make_agent("+2250711111201")
        self.agent_b = _make_agent("+2250711111202")
        self.client_user = _make_client_user("+2250711111203")
        self.property_a = _make_property(self.agent_a, "Bien de A")
        self.property_b = _make_property(self.agent_b, "Bien de B")

    def test_returns_only_own_properties(self):
        self.client.force_authenticate(user=self.agent_a)
        response = self.client.get("/api/agent/properties/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        titles = [p["title"] for p in response.data["results"]]
        self.assertIn("Bien de A", titles)
        self.assertNotIn("Bien de B", titles)

    def test_client_cannot_access(self):
        self.client.force_authenticate(user=self.client_user)
        response = self.client.get("/api/agent/properties/")
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)


class InstantPublicationTests(APITestCase):
    """Aucune validation admin : une annonce créée est "disponible" (donc
    publique) immédiatement — pas de statut "pending", pas d'approbation."""

    def setUp(self):
        self.agent = _make_agent("+2250711111301")

    def _new_property_payload(self, title="Bien instantane"):
        return {
            "title": title,
            "category": "Studio",
            "type": "logement",
            "transaction_type": "location",
            "price": 100000,
            "commune": "Cocody",
            "district": "Vallon",
        }

    def test_property_is_published_immediately_after_creation(self):
        self.client.force_authenticate(user=self.agent)
        response = self.client.post(
            "/api/properties/", self._new_property_payload(), format="json"
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data["status"], "disponible")

    def test_property_is_immediately_visible_in_public_list(self):
        self.client.force_authenticate(user=self.agent)
        create_response = self.client.post(
            "/api/properties/", self._new_property_payload("Bien tout juste publie"), format="json"
        )
        new_id = create_response.data["id"]

        # Un client anonyme, sans lien avec l'agent, doit déjà la voir.
        self.client.force_authenticate(user=None)
        list_response = self.client.get("/api/properties/")
        ids = [p["id"] for p in list_response.data["results"]]
        self.assertIn(new_id, ids)

    def test_agent_can_delete_own_property(self):
        property_obj = _make_property(self.agent, "A supprimer")
        self.client.force_authenticate(user=self.agent)
        response = self.client.delete(f"/api/properties/{property_obj.id}/")
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)
        self.assertFalse(Property.objects.filter(pk=property_obj.pk).exists())

    def test_deleting_a_property_with_reservations_returns_a_clean_conflict_not_a_500(self):
        from reservations.models import Reservation

        property_obj = _make_property(self.agent, "Avec reservation")
        client_user = _make_client_user("+2250711111302")
        Reservation.objects.create(
            property=property_obj, user=client_user, rent=100000, deposit=0, advance=0
        )

        self.client.force_authenticate(user=self.agent)
        response = self.client.delete(f"/api/properties/{property_obj.id}/")

        self.assertEqual(response.status_code, status.HTTP_409_CONFLICT)
        self.assertTrue(Property.objects.filter(pk=property_obj.pk).exists())
