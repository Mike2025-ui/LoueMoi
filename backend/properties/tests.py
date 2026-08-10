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


def _make_property_at(agent, title, latitude, longitude):
    return Property.objects.create(
        title=title,
        category="Studio",
        type="logement",
        transaction_type="location",
        price=100000,
        commune="Cocody",
        district="Vallon",
        agent=agent,
        latitude=latitude,
        longitude=longitude,
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


class PropertyCoordinateValidationTests(APITestCase):
    """Tests 1 à 5 (cahier des charges géolocalisation, section 28)."""

    def setUp(self):
        self.agent = _make_agent("+2250711112001")

    def _payload(self, **overrides):
        payload = {
            "title": "Bien geo",
            "category": "Studio",
            "type": "logement",
            "transaction_type": "location",
            "price": 100000,
            "commune": "Cocody",
            "district": "Vallon",
        }
        payload.update(overrides)
        return payload

    def test_create_property_with_valid_coordinates(self):
        self.client.force_authenticate(user=self.agent)
        response = self.client.post(
            "/api/properties/",
            self._payload(latitude=5.359951, longitude=-4.008256),
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertAlmostEqual(float(response.data["latitude"]), 5.359951, places=5)
        self.assertAlmostEqual(float(response.data["longitude"]), -4.008256, places=5)

    def test_non_numeric_coordinate_rejected(self):
        self.client.force_authenticate(user=self.agent)
        response = self.client.post(
            "/api/properties/",
            self._payload(latitude="abc", longitude=-4.008256),
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_latitude_out_of_range_rejected(self):
        self.client.force_authenticate(user=self.agent)
        response = self.client.post(
            "/api/properties/",
            self._payload(latitude=500, longitude=-4.008256),
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("latitude", response.data)

    def test_longitude_out_of_range_rejected(self):
        self.client.force_authenticate(user=self.agent)
        response = self.client.post(
            "/api/properties/",
            self._payload(latitude=5.359951, longitude=-900),
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("longitude", response.data)

    def test_property_without_coordinates_still_accepted(self):
        """Compatibilité : les annonces (existantes ou nouvelles) sans
        position doivent rester acceptées — aucune régression."""
        self.client.force_authenticate(user=self.agent)
        response = self.client.post("/api/properties/", self._payload(), format="json")
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertIsNone(response.data["latitude"])
        self.assertIsNone(response.data["longitude"])

    def test_only_one_coordinate_provided_is_rejected(self):
        self.client.force_authenticate(user=self.agent)
        response = self.client.post(
            "/api/properties/", self._payload(latitude=5.359951), format="json"
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)


class PropertyLocationPermissionTests(APITestCase):
    """Tests 9, 10, 11 : mêmes permissions que le reste de l'annonce —
    aucune règle spéciale pour latitude/longitude."""

    def setUp(self):
        self.agent_a = _make_agent("+2250711112002")
        self.agent_b = _make_agent("+2250711112003")
        self.client_user = _make_client_user("+2250711112004")
        self.property_a = _make_property(self.agent_a, "Bien de A")

    def test_agent_can_set_location_on_own_property(self):
        self.client.force_authenticate(user=self.agent_a)
        response = self.client.patch(
            f"/api/properties/{self.property_a.id}/",
            {"latitude": 5.35, "longitude": -4.0},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.property_a.refresh_from_db()
        self.assertAlmostEqual(float(self.property_a.latitude), 5.35, places=4)

    def test_client_cannot_modify_property_location(self):
        self.client.force_authenticate(user=self.client_user)
        response = self.client.patch(
            f"/api/properties/{self.property_a.id}/",
            {"latitude": 5.35, "longitude": -4.0},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_agent_b_cannot_modify_agent_a_property_location(self):
        self.client.force_authenticate(user=self.agent_b)
        response = self.client.patch(
            f"/api/properties/{self.property_a.id}/",
            {"latitude": 5.35, "longitude": -4.0},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)


class PropertyNearbyTests(APITestCase):
    """Tests 6, 7, 8, 12, 13 (cahier des charges géolocalisation)."""

    # Cocody Angré, Abidjan.
    ORIGIN_LAT = 5.359951
    ORIGIN_LNG = -4.008256

    def setUp(self):
        self.agent = _make_agent("+2250711112005")
        self.close_property = _make_property_at(
            self.agent, "Tout proche", self.ORIGIN_LAT, self.ORIGIN_LNG
        )
        # ~11 km de l'origine (Yopougon).
        self.far_property = _make_property_at(self.agent, "Loin", 5.32, -4.10)
        self.no_location_property = _make_property(self.agent, "Sans position")

    def _nearby(self, **params):
        query = "&".join(f"{k}={v}" for k, v in params.items())
        return self.client.get(f"/api/properties/nearby/?{query}")

    def test_nearby_returns_properties_within_radius(self):
        response = self._nearby(latitude=self.ORIGIN_LAT, longitude=self.ORIGIN_LNG, radius=5)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        ids = [p["id"] for p in response.data["results"]]
        self.assertIn(self.close_property.id, ids)

    def test_nearby_excludes_properties_outside_radius(self):
        response = self._nearby(latitude=self.ORIGIN_LAT, longitude=self.ORIGIN_LNG, radius=5)
        ids = [p["id"] for p in response.data["results"]]
        self.assertNotIn(self.far_property.id, ids)

    def test_nearby_with_wider_radius_includes_far_property(self):
        response = self._nearby(latitude=self.ORIGIN_LAT, longitude=self.ORIGIN_LNG, radius=20)
        ids = [p["id"] for p in response.data["results"]]
        self.assertIn(self.far_property.id, ids)

    def test_nearby_excludes_properties_without_coordinates(self):
        response = self._nearby(latitude=self.ORIGIN_LAT, longitude=self.ORIGIN_LNG, radius=100)
        ids = [p["id"] for p in response.data["results"]]
        self.assertNotIn(self.no_location_property.id, ids)

    def test_nearby_returns_correct_distance(self):
        response = self._nearby(latitude=self.ORIGIN_LAT, longitude=self.ORIGIN_LNG, radius=1)
        result = next(p for p in response.data["results"] if p["id"] == self.close_property.id)
        self.assertAlmostEqual(result["distance_km"], 0.0, places=1)

    def test_nearby_only_returns_public_properties(self):
        disabled = _make_property_at(self.agent, "Desactivee", self.ORIGIN_LAT, self.ORIGIN_LNG)
        disabled.status = "disabled"
        disabled.save(update_fields=["status"])

        response = self._nearby(latitude=self.ORIGIN_LAT, longitude=self.ORIGIN_LNG, radius=5)
        ids = [p["id"] for p in response.data["results"]]
        self.assertNotIn(disabled.id, ids)

    def test_nearby_is_accessible_anonymously(self):
        response = self._nearby(latitude=self.ORIGIN_LAT, longitude=self.ORIGIN_LNG, radius=5)
        self.assertEqual(response.status_code, status.HTTP_200_OK)

    def test_nearby_rejects_missing_latitude(self):
        response = self.client.get(f"/api/properties/nearby/?longitude={self.ORIGIN_LNG}&radius=5")
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_nearby_rejects_out_of_range_latitude(self):
        response = self._nearby(latitude=500, longitude=self.ORIGIN_LNG, radius=5)
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_nearby_rejects_invalid_radius(self):
        response = self._nearby(latitude=self.ORIGIN_LAT, longitude=self.ORIGIN_LNG, radius=-5)
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
