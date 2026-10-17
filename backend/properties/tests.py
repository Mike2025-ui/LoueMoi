import struct
from datetime import timedelta

from django.conf import settings
from django.contrib.auth import get_user_model
from django.core.files.storage import default_storage
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import RequestFactory
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APITestCase

from config.media_views import serve_media

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


def _make_bailleur(phone):
    return User.objects.create_user(
        phone=phone, password="secret123", first_name="Bailleur", last_name=phone,
        role=User.ROLE_BAILLEUR,
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


def _make_fake_mp4_bytes(duration_seconds=10, timescale=1000):
    """Construit un MP4/ISO-BMFF minimal (ftyp + moov/mvhd) — juste assez
    pour que properties.video_utils.get_mp4_duration_seconds puisse en
    extraire une durée, sans dépendance à un vrai encodeur vidéo."""
    mvhd_body = bytes([0]) + bytes(3) + struct.pack(
        ">IIII", 0, 0, timescale, int(duration_seconds * timescale)
    )
    mvhd_box = struct.pack(">I", 8 + len(mvhd_body)) + b"mvhd" + mvhd_body
    moov_box = struct.pack(">I", 8 + len(mvhd_box)) + b"moov" + mvhd_box
    ftyp_body = b"isom" + struct.pack(">I", 0) + b"isomiso2mp41"
    ftyp_box = struct.pack(">I", 8 + len(ftyp_body)) + b"ftyp" + ftyp_body
    return ftyp_box + moov_box


def _make_video_file(name="clip.mp4", duration_seconds=10, extra_padding=0):
    content = _make_fake_mp4_bytes(duration_seconds) + (b"0" * extra_padding)
    return SimpleUploadedFile(name, content, content_type="video/mp4")


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


class SoldPropertiesScopingTests(APITestCase):
    """Écran "Propriétés vendues" (mission de finalisation) : réutilise
    /api/agent/properties/, aucun nouvel endpoint — ces tests vérifient donc
    que le scoping déjà en place s'applique correctement aux biens vendus
    en particulier (jamais ceux d'un autre agent, jamais ceux d'un
    bailleur), et que le statut vendue/occupee reste cohérent avec
    transaction_type."""

    def setUp(self):
        self.agent = _make_agent("+2250711111210")
        self.other_agent = _make_agent("+2250711111211")
        self.bailleur = _make_bailleur("+2250711111212")

        self.agent_sold = Property.objects.create(
            title="Villa vendue par l'agent", category="Villa", type="logement",
            transaction_type="vente", price=50000000, commune="X", district="Y",
            agent=self.agent, status="vendue",
        )
        Property.objects.create(
            title="Villa encore disponible", category="Villa", type="logement",
            transaction_type="vente", price=40000000, commune="X", district="Y",
            agent=self.agent, status="disponible",
        )
        Property.objects.create(
            title="Studio loué (pas vendu)", category="Studio", type="logement",
            transaction_type="location", price=100000, commune="X", district="Y",
            agent=self.agent, status="occupee",
        )
        Property.objects.create(
            title="Villa vendue par un autre agent", category="Villa", type="logement",
            transaction_type="vente", price=60000000, commune="X", district="Y",
            agent=self.other_agent, status="vendue",
        )
        Property.objects.create(
            title="Villa vendue par un bailleur", category="Villa", type="logement",
            transaction_type="vente", price=70000000, commune="X", district="Y",
            agent=self.bailleur, status="vendue",
        )

    def test_agent_sees_only_their_own_properties_including_sold_ones(self):
        self.client.force_authenticate(user=self.agent)
        response = self.client.get("/api/agent/properties/")
        titles = {p["title"]: p["status"] for p in response.data["results"]}

        self.assertEqual(titles.get("Villa vendue par l'agent"), "vendue")
        self.assertIn("Villa encore disponible", titles)
        self.assertIn("Studio loué (pas vendu)", titles)
        self.assertNotIn("Villa vendue par un autre agent", titles)
        self.assertNotIn("Villa vendue par un bailleur", titles)

    def test_a_rental_property_can_never_be_marked_vendue(self):
        location_property = Property.objects.create(
            title="Studio en location", category="Studio", type="logement",
            transaction_type="location", price=100000, commune="X", district="Y",
            agent=self.agent,
        )
        self.client.force_authenticate(user=self.agent)
        response = self.client.post(
            f"/api/properties/{location_property.id}/status/", {"status": "vendue"}, format="json"
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_a_sale_property_can_be_marked_vendue(self):
        self.client.force_authenticate(user=self.agent)
        response = self.client.post(
            "/api/properties/{}/status/".format(
                Property.objects.get(title="Villa encore disponible").id
            ),
            {"status": "vendue"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)

    def test_sold_property_is_never_reservable(self):
        client_user = _make_client_user("+2250711111213")
        self.client.force_authenticate(user=client_user)
        response = self.client.post(
            "/api/reservations/",
            {
                "property_id": self.agent_sold.id,
                "rent": self.agent_sold.price,
                "deposit": 0,
                "advance": 0,
            },
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_client_cannot_change_a_property_status(self):
        client_user = _make_client_user("+2250711111214")
        self.client.force_authenticate(user=client_user)
        response = self.client.post(
            f"/api/properties/{self.agent_sold.id}/status/", {"status": "disponible"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_only_the_real_owner_can_change_the_status(self):
        self.client.force_authenticate(user=self.other_agent)
        response = self.client.post(
            f"/api/properties/{self.agent_sold.id}/status/", {"status": "disponible"},
            format="json",
        )
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

    def test_coordinate_with_more_than_6_decimal_places_rejected(self):
        """Reproduit le bug réel observé sur téléphone : Geolocator/flutter_map
        renvoient des doubles avec 15+ décimales (ex: 5.355410123456), que
        DecimalField(decimal_places=6) rejette légitimement. Flutter doit
        arrondir avant l'envoi (voir core/utils/geo.dart::normalizeCoordinate) —
        ce test documente le contrat que ce correctif respecte désormais."""
        self.client.force_authenticate(user=self.agent)
        response = self.client.post(
            "/api/properties/",
            self._payload(latitude=5.355410123456, longitude=-3.991310987654),
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_coordinate_rounded_to_6_decimals_is_accepted(self):
        """Même scénario que le bug réel (Cocody, Abata) mais avec les
        coordonnées normalisées à 6 décimales — doit réussir."""
        self.client.force_authenticate(user=self.agent)
        response = self.client.post(
            "/api/properties/",
            self._payload(price=30000, latitude=5.35541, longitude=-3.99131),
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertAlmostEqual(float(response.data["latitude"]), 5.35541, places=5)
        self.assertAlmostEqual(float(response.data["longitude"]), -3.99131, places=5)


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


class BailleurPropertyPermissionTests(APITestCase):
    """Tests 9 à 14 (mission finalisation) : bailleur et agent sont deux
    rôles indépendants, mais soumis exactement aux mêmes règles de
    propriété sur /api/properties/ (même permission CanOwnProperties +
    IsPropertyOwnerOrReadOnly)."""

    def setUp(self):
        self.bailleur_a = _make_bailleur("+2250711113001")
        self.bailleur_b = _make_bailleur("+2250711113002")
        self.client_user = _make_client_user("+2250711113003")
        self.property_a = _make_property(self.bailleur_a, "Bien du bailleur A")

    def _payload(self, title="Nouveau bien bailleur"):
        return {
            "title": title,
            "category": "Studio",
            "type": "logement",
            "transaction_type": "location",
            "price": 150000,
            "commune": "Cocody",
            "district": "Angré",
        }

    def test_bailleur_can_publish(self):
        self.client.force_authenticate(user=self.bailleur_b)
        response = self.client.post("/api/properties/", self._payload(), format="json")
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data["status"], "disponible")
        self.assertEqual(response.data["agent"]["id"], self.bailleur_b.id)

    def test_client_cannot_publish(self):
        self.client.force_authenticate(user=self.client_user)
        response = self.client.post("/api/properties/", self._payload(), format="json")
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_bailleur_can_modify_own_property(self):
        self.client.force_authenticate(user=self.bailleur_a)
        response = self.client.patch(
            f"/api/properties/{self.property_a.id}/", {"title": "Titre modifié"}, format="json"
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.property_a.refresh_from_db()
        self.assertEqual(self.property_a.title, "Titre modifié")

    def test_bailleur_cannot_modify_another_bailleurs_property(self):
        self.client.force_authenticate(user=self.bailleur_b)
        response = self.client.patch(
            f"/api/properties/{self.property_a.id}/", {"title": "Piraté"}, format="json"
        )
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_bailleur_can_delete_own_property(self):
        property_obj = _make_property(self.bailleur_a, "À supprimer")
        self.client.force_authenticate(user=self.bailleur_a)
        response = self.client.delete(f"/api/properties/{property_obj.id}/")
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)

    def test_bailleur_cannot_delete_another_bailleurs_property(self):
        self.client.force_authenticate(user=self.bailleur_b)
        response = self.client.delete(f"/api/properties/{self.property_a.id}/")
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
        self.assertTrue(Property.objects.filter(pk=self.property_a.pk).exists())

    def test_agent_can_see_bailleurs_public_properties(self):
        # La liste publique mélange agents et bailleurs sans distinction.
        agent = _make_agent("+2250711113004")
        self.client.force_authenticate(user=agent)
        response = self.client.get("/api/properties/")
        ids = [p["id"] for p in response.data["results"]]
        self.assertIn(self.property_a.id, ids)


class CrossRoleOwnershipTests(APITestCase):
    """Décision métier définitive : propriété exclusive à l'auteur, aucun
    transfert entre acteurs. IsPropertyOwnerOrReadOnly ne compare que
    `obj.agent_id == request.user.id` (voir properties/permissions.py),
    sans jamais regarder les rôles — les tests existants ne couvraient que
    même-rôle (agent vs agent, bailleur vs bailleur) ; ceux-ci couvrent
    explicitement les deux scénarios cross-rôle nommés dans la décision, qui
    n'avaient jamais été vérifiés par un test dédié."""

    def setUp(self):
        self.agent = _make_agent("+2250711113005")
        self.bailleur = _make_bailleur("+2250711113006")
        self.bailleur_property = _make_property(self.bailleur, "Bien du bailleur")
        self.agent_property = _make_property(self.agent, "Bien de l'agent")

    def test_agent_cannot_take_possession_of_a_bailleurs_property(self):
        self.client.force_authenticate(user=self.agent)
        response = self.client.patch(
            f"/api/properties/{self.bailleur_property.id}/",
            {"title": "Pris par un agent"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
        self.bailleur_property.refresh_from_db()
        self.assertEqual(self.bailleur_property.agent_id, self.bailleur.id)
        self.assertEqual(self.bailleur_property.title, "Bien du bailleur")

    def test_bailleur_cannot_take_possession_of_an_agents_property(self):
        self.client.force_authenticate(user=self.bailleur)
        response = self.client.patch(
            f"/api/properties/{self.agent_property.id}/",
            {"title": "Pris par un bailleur"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
        self.agent_property.refresh_from_db()
        self.assertEqual(self.agent_property.agent_id, self.agent.id)
        self.assertEqual(self.agent_property.title, "Bien de l'agent")

    def test_agent_cannot_delete_a_bailleurs_property(self):
        self.client.force_authenticate(user=self.agent)
        response = self.client.delete(f"/api/properties/{self.bailleur_property.id}/")
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
        self.assertTrue(Property.objects.filter(pk=self.bailleur_property.pk).exists())

    def test_bailleur_cannot_delete_an_agents_property(self):
        self.client.force_authenticate(user=self.bailleur)
        response = self.client.delete(f"/api/properties/{self.agent_property.id}/")
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
        self.assertTrue(Property.objects.filter(pk=self.agent_property.pk).exists())

    def test_property_serializer_never_accepts_a_client_supplied_agent(self):
        """`agent` est un AgentSerializer(read_only=True) sur le serializer
        (jamais un simple read_only_fields) : même en l'envoyant
        explicitement dans le payload, il ne peut jamais être détourné vers
        un autre propriétaire — création ou modification."""
        other_bailleur = _make_bailleur("+2250711113007")
        self.client.force_authenticate(user=self.agent)
        response = self.client.patch(
            f"/api/properties/{self.agent_property.id}/",
            {"agent": other_bailleur.id},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.agent_property.refresh_from_db()
        self.assertEqual(self.agent_property.agent_id, self.agent.id)


class PropertyRenewTests(APITestCase):
    """Décision métier retenue (mission de finalisation) : une annonce reste
    valide 30 jours (Property.PROPERTY_VALIDITY_DAYS) après publication.
    "Reconduire un bien" fixe une nouvelle période de 30 jours à partir de
    maintenant, réservé au propriétaire réel — jamais de doublon."""

    def setUp(self):
        self.agent = _make_agent("+2250711116001")
        self.other_agent = _make_agent("+2250711116002")
        self.client_user = _make_client_user("+2250711116003")
        self.property_obj = Property.objects.create(
            title="Bien à reconduire", category="Studio", type="logement",
            transaction_type="location", price=100000, commune="X", district="Y",
            agent=self.agent,
        )

    def test_owner_can_renew_own_property(self):
        self.property_obj.status = "annulee"
        self.property_obj.save(update_fields=["status"])
        original_updated_at = self.property_obj.updated_at
        self.client.force_authenticate(user=self.agent)
        response = self.client.post(f"/api/properties/{self.property_obj.id}/renew/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.property_obj.refresh_from_db()
        self.assertEqual(self.property_obj.status, "disponible")
        self.assertGreater(self.property_obj.updated_at, original_updated_at)
        # Aucun doublon : toujours la même annonce, mêmes données.
        self.assertEqual(Property.objects.filter(title="Bien à reconduire").count(), 1)
        self.assertEqual(response.data["title"], "Bien à reconduire")

    def test_renew_gives_a_fresh_30_day_period(self):
        self.property_obj.status = "annulee"
        self.property_obj.expires_at = timezone.now() - timedelta(days=1)  # déjà expirée
        self.property_obj.save(update_fields=["status", "expires_at"])

        self.client.force_authenticate(user=self.agent)
        response = self.client.post(f"/api/properties/{self.property_obj.id}/renew/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)

        self.property_obj.refresh_from_db()
        self.assertEqual(self.property_obj.status, "disponible")
        self.assertGreater(self.property_obj.expires_at, timezone.now())
        expected = self.property_obj.published_at + timedelta(days=30)
        self.assertAlmostEqual(
            self.property_obj.expires_at, expected, delta=timedelta(seconds=5)
        )

    def test_renew_rejected_if_not_annulee(self):
        self.property_obj.status = "disponible"
        self.property_obj.save(update_fields=["status"])
        self.client.force_authenticate(user=self.agent)
        response = self.client.post(f"/api/properties/{self.property_obj.id}/renew/")
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_renew_rejected_if_accomplie(self):
        self.property_obj.status = "accomplie"
        self.property_obj.save(update_fields=["status"])
        self.client.force_authenticate(user=self.agent)
        response = self.client.post(f"/api/properties/{self.property_obj.id}/renew/")
        self.assertIn(
            response.status_code, [status.HTTP_400_BAD_REQUEST, status.HTTP_404_NOT_FOUND]
        )

    def test_another_agent_cannot_renew(self):
        self.client.force_authenticate(user=self.other_agent)
        response = self.client.post(f"/api/properties/{self.property_obj.id}/renew/")
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_client_cannot_renew(self):
        self.client.force_authenticate(user=self.client_user)
        response = self.client.post(f"/api/properties/{self.property_obj.id}/renew/")
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)


class PropertyExpirationTests(APITestCase):
    """Une annonce fraîchement créée reçoit 30 jours de validité ; une
    annonce expirée disparaît des résultats publics (liste et détail) pour
    tout le monde SAUF son propriétaire, qui doit pouvoir la retrouver pour
    la reconduire. expires_at NULL (annonces historiques, avant ce système)
    n'expire jamais — aucune disparition rétroactive."""

    def setUp(self):
        self.owner = _make_agent("+2250711116101")
        self.other_user = _make_client_user("+2250711116102")

    def test_new_property_gets_a_30_day_validity_period(self):
        self.client.force_authenticate(user=self.owner)
        response = self.client.post(
            "/api/properties/",
            {
                "title": "Bien neuf", "category": "Studio", "type": "logement",
                "transaction_type": "location", "price": 100000, "commune": "X", "district": "Y",
            },
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        created = Property.objects.get(pk=response.data["id"])
        self.assertIsNotNone(created.published_at)
        self.assertAlmostEqual(
            created.expires_at, created.published_at + timedelta(days=30),
            delta=timedelta(seconds=5),
        )

    def test_expired_property_is_hidden_from_other_users_in_list_and_detail(self):
        expired = Property.objects.create(
            title="Bien expiré", category="Studio", type="logement",
            transaction_type="location", price=100000, commune="X", district="Y",
            agent=self.owner, expires_at=timezone.now() - timedelta(days=1),
        )
        self.client.force_authenticate(user=self.other_user)

        list_response = self.client.get("/api/properties/")
        ids = [p["id"] for p in list_response.data["results"]]
        self.assertNotIn(expired.id, ids)

        detail_response = self.client.get(f"/api/properties/{expired.id}/")
        self.assertEqual(detail_response.status_code, status.HTTP_404_NOT_FOUND)

    def test_expired_property_stays_visible_to_its_owner(self):
        expired = Property.objects.create(
            title="Bien expiré", category="Studio", type="logement",
            transaction_type="location", price=100000, commune="X", district="Y",
            agent=self.owner, expires_at=timezone.now() - timedelta(days=1),
        )
        self.client.force_authenticate(user=self.owner)

        list_response = self.client.get("/api/properties/")
        ids = [p["id"] for p in list_response.data["results"]]
        self.assertIn(expired.id, ids)

        detail_response = self.client.get(f"/api/properties/{expired.id}/")
        self.assertEqual(detail_response.status_code, status.HTTP_200_OK)

    def test_expired_property_is_also_hidden_from_anonymous_users(self):
        expired = Property.objects.create(
            title="Bien expiré", category="Studio", type="logement",
            transaction_type="location", price=100000, commune="X", district="Y",
            agent=self.owner, expires_at=timezone.now() - timedelta(days=1),
        )
        response = self.client.get("/api/properties/")
        ids = [p["id"] for p in response.data["results"]]
        self.assertNotIn(expired.id, ids)

    def test_property_with_no_expiry_date_never_expires(self):
        """Grandfather clause : les annonces publiées avant l'introduction
        de ce système (expires_at NULL en base) restent visibles — jamais
        de disparition rétroactive au déploiement de cette fonctionnalité."""
        never_expires = Property.objects.create(
            title="Bien historique", category="Studio", type="logement",
            transaction_type="location", price=100000, commune="X", district="Y",
            agent=self.owner,
        )
        self.assertIsNone(never_expires.expires_at)
        self.client.force_authenticate(user=self.other_user)
        response = self.client.get("/api/properties/")
        ids = [p["id"] for p in response.data["results"]]
        self.assertIn(never_expires.id, ids)


class PropertyFilterTests(APITestCase):
    """Section 3 (mission corrections UX) : chaque paramètre de filtre côté
    Django (properties/filters.py::PropertyFilter) doit réellement filtrer,
    seul et combiné avec d'autres."""

    def setUp(self):
        agent = _make_agent("+2250711117101")
        self.appart_cocody = Property.objects.create(
            title="Appart Cocody", category="Studio", type="logement",
            transaction_type="location", price=300000, commune="Cocody", district="Angre",
            agent=agent,
        )
        self.appart_cocody_cher = Property.objects.create(
            title="Appart Cocody cher", category="Studio", type="logement",
            transaction_type="location", price=800000, commune="Cocody", district="Riviera",
            agent=agent,
        )
        self.villa_cocody_vente = Property.objects.create(
            title="Villa Cocody à vendre", category="Villa", type="logement",
            transaction_type="vente", price=400000, commune="Cocody", district="Angre",
            agent=agent,
        )
        self.terrain_yopougon = Property.objects.create(
            title="Terrain Yopougon", category="Terrain", type="terrain",
            transaction_type="vente", price=200000, commune="Yopougon", district="Selmer",
            agent=agent,
        )

    def _ids(self, response):
        return {p["id"] for p in response.data["results"]}

    def test_filter_by_transaction_type(self):
        response = self.client.get("/api/properties/?transaction_type=vente")
        ids = self._ids(response)
        self.assertIn(self.villa_cocody_vente.id, ids)
        self.assertIn(self.terrain_yopougon.id, ids)
        self.assertNotIn(self.appart_cocody.id, ids)

    def test_filter_by_type(self):
        response = self.client.get("/api/properties/?type=terrain")
        ids = self._ids(response)
        self.assertEqual(ids, {self.terrain_yopougon.id})

    def test_filter_by_category(self):
        response = self.client.get("/api/properties/?category=Villa")
        ids = self._ids(response)
        self.assertEqual(ids, {self.villa_cocody_vente.id})

    def test_filter_by_commune_case_insensitive_partial_match(self):
        response = self.client.get("/api/properties/?commune=cocody")
        ids = self._ids(response)
        self.assertEqual(
            ids, {self.appart_cocody.id, self.appart_cocody_cher.id, self.villa_cocody_vente.id}
        )
        self.assertNotIn(self.terrain_yopougon.id, ids)

    def test_filter_by_district(self):
        response = self.client.get("/api/properties/?district=Angre")
        ids = self._ids(response)
        self.assertEqual(ids, {self.appart_cocody.id, self.villa_cocody_vente.id})

    def test_filter_by_budget_min(self):
        response = self.client.get("/api/properties/?budget_min=300000")
        ids = self._ids(response)
        self.assertIn(self.appart_cocody.id, ids)
        self.assertIn(self.appart_cocody_cher.id, ids)
        self.assertNotIn(self.terrain_yopougon.id, ids)

    def test_filter_by_budget_max(self):
        response = self.client.get("/api/properties/?budget_max=400000")
        ids = self._ids(response)
        self.assertIn(self.appart_cocody.id, ids)
        self.assertIn(self.villa_cocody_vente.id, ids)
        self.assertIn(self.terrain_yopougon.id, ids)
        self.assertNotIn(self.appart_cocody_cher.id, ids)

    def test_combination_of_several_filters(self):
        """Exemple exact du cahier des charges : commune=Cocody,
        type=logement, prix max=500000. villa_cocody_vente correspond aussi
        (type="logement", catégorie "Villa") : la combinaison ne filtre pas
        sur transaction_type ici, donc les deux biens location ET vente à
        Cocody sous 500000 doivent apparaître — mais pas l'appart trop cher
        ni le terrain d'une autre commune."""
        response = self.client.get(
            "/api/properties/?commune=Cocody&type=logement&budget_max=500000"
        )
        ids = self._ids(response)
        self.assertEqual(ids, {self.appart_cocody.id, self.villa_cocody_vente.id})
        self.assertNotIn(self.appart_cocody_cher.id, ids)
        self.assertNotIn(self.terrain_yopougon.id, ids)

    def test_no_match_returns_empty_not_everything(self):
        response = self.client.get("/api/properties/?commune=VilleInexistante")
        self.assertEqual(self._ids(response), set())


class PropertyMarkStatusTests(APITestCase):
    """POST /api/properties/{id}/status/ — "occupee" (bien loué) et "vendue"
    (transaction terminée) sont deux statuts distincts, jamais
    interchangeables : chacun n'a de sens que pour son transaction_type."""

    def setUp(self):
        self.owner = _make_agent("+2250711118001")
        self.outsider = _make_agent("+2250711118002")
        self.location_property = Property.objects.create(
            title="Studio", category="Studio", type="logement", transaction_type="location",
            price=100000, commune="X", district="Y", agent=self.owner,
        )
        self.vente_property = Property.objects.create(
            title="Villa", category="Villa", type="logement", transaction_type="vente",
            price=50000000, commune="X", district="Y", agent=self.owner,
        )

    def test_owner_can_mark_a_rental_property_occupied(self):
        self.client.force_authenticate(user=self.owner)
        response = self.client.post(
            f"/api/properties/{self.location_property.id}/status/",
            {"status": "occupee"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.location_property.refresh_from_db()
        self.assertEqual(self.location_property.status, "occupee")

    def test_rental_property_cannot_be_marked_vendue(self):
        self.client.force_authenticate(user=self.owner)
        response = self.client.post(
            f"/api/properties/{self.location_property.id}/status/",
            {"status": "vendue"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.location_property.refresh_from_db()
        self.assertEqual(self.location_property.status, "disponible")

    def test_owner_can_mark_a_sale_property_vendue(self):
        self.client.force_authenticate(user=self.owner)
        response = self.client.post(
            f"/api/properties/{self.vente_property.id}/status/",
            {"status": "vendue"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.vente_property.refresh_from_db()
        self.assertEqual(self.vente_property.status, "vendue")

    def test_sale_property_cannot_be_marked_occupee(self):
        self.client.force_authenticate(user=self.owner)
        response = self.client.post(
            f"/api/properties/{self.vente_property.id}/status/",
            {"status": "occupee"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.vente_property.refresh_from_db()
        self.assertEqual(self.vente_property.status, "disponible")

    def test_sale_property_can_go_back_to_disponible(self):
        self.vente_property.status = "vendue"
        self.vente_property.save(update_fields=["status"])
        self.client.force_authenticate(user=self.owner)
        response = self.client.post(
            f"/api/properties/{self.vente_property.id}/status/",
            {"status": "disponible"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)

    def test_non_owner_cannot_mark_status(self):
        self.client.force_authenticate(user=self.outsider)
        response = self.client.post(
            f"/api/properties/{self.vente_property.id}/status/",
            {"status": "vendue"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
        self.vente_property.refresh_from_db()
        self.assertEqual(self.vente_property.status, "disponible")


class PropertyPaginationOrderingTests(APITestCase):
    """Audit "doublons dans la recherche" (mission de stabilisation) :
    Property.Meta.ordering triait uniquement par -created_at, qui n'est pas
    un ordre total — deux annonces publiées à la même seconde (rafale de
    publications, fixtures, tests) n'avaient aucun ordre garanti entre elles
    d'une requête à l'autre. Avec LIMIT/OFFSET (pagination par page), ça peut
    faire apparaître deux fois la même annonce sur deux pages, ou en sauter
    une. Le tiebreaker -id (voir properties/models.py) rend l'ordre total et
    donc stable."""

    def setUp(self):
        agent = _make_agent("+2250711117201")
        # created_at est auto_now_add (non écrivable à la création) : on force
        # la même valeur après coup via .update(), qui ne passe pas par le
        # ORM save() et échappe donc à auto_now_add — seul moyen de
        # reproduire une vraie égalité de timestamp en test.
        self.properties = [_make_property(agent, title=f"Bien {i}") for i in range(5)]
        same_instant = self.properties[0].created_at
        Property.objects.filter(
            id__in=[p.id for p in self.properties]
        ).update(created_at=same_instant)

    def test_ordering_is_a_total_order_even_with_tied_created_at(self):
        """La requête ORM brute, exécutée deux fois, renvoie exactement la
        même séquence d'ids — condition nécessaire pour qu'une pagination
        par page ne duplique ni ne saute une ligne."""
        first_run = list(Property.objects.filter(id__in=[p.id for p in self.properties])
                          .values_list("id", flat=True))
        second_run = list(Property.objects.filter(id__in=[p.id for p in self.properties])
                           .values_list("id", flat=True))
        self.assertEqual(first_run, second_run)
        # Décroissant sur l'id (tiebreaker), donc déductible sans ambiguïté.
        self.assertEqual(first_run, sorted((p.id for p in self.properties), reverse=True))

    def test_paginated_api_never_repeats_or_skips_a_property_across_pages(self):
        page1 = self.client.get("/api/properties/?page=1&page_size=2").data["results"]
        page2 = self.client.get("/api/properties/?page=2&page_size=2").data["results"]
        page3 = self.client.get("/api/properties/?page=3&page_size=2").data["results"]
        all_ids = [p["id"] for p in page1 + page2 + page3]

        expected_ids = [p.id for p in self.properties]
        self.assertCountEqual(all_ids, expected_ids)  # aucun manquant, aucun en trop
        self.assertEqual(len(all_ids), len(set(all_ids)))  # aucun doublon


class PropertyVideoTests(APITestCase):
    """Point 2 — vidéo dans les annonces. POST/DELETE
    /api/properties/{id}/video/ : une vidéo facultative, un maximum d'une
    par annonce, MP4 uniquement, ≤50 Mo, ≤60 s, réservée au propriétaire
    réel. Fonctionnalité distincte de la vidéo de messagerie."""

    def setUp(self):
        self.owner = _make_agent("+2250711119001")
        self.other_agent = _make_agent("+2250711119002")
        self.bailleur = _make_bailleur("+2250711119003")
        self.client_user = _make_client_user("+2250711119004")
        self.property = _make_property(self.owner, "Bien avec vidéo")
        self.url = f"/api/properties/{self.property.id}/video/"

    def tearDown(self):
        # Certains tests suppriment self.property elle-même (nettoyage du
        # fichier vidéo) — rien à nettoyer de plus dans ce cas.
        try:
            self.property.refresh_from_db()
        except Property.DoesNotExist:
            return
        if self.property.video:
            self.property.video.delete(save=False)

    # 1. Le propriétaire peut ajouter une vidéo.
    def test_owner_can_add_video(self):
        self.client.force_authenticate(user=self.owner)
        response = self.client.post(self.url, {"video": _make_video_file()}, format="multipart")
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.property.refresh_from_db()
        self.assertTrue(bool(self.property.video))
        self.assertIsNotNone(response.data["video"])

    def test_video_url_is_absolute_not_a_bare_media_path(self):
        """Correction (audit vidéo) : sans context={"request": request}, DRF
        renvoie l'URL relative brute (ex. "/media/properties/1/video/x.mp4")
        au lieu de la construire via request.build_absolute_uri() — un
        téléphone ne peut alors atteindre aucun hôte (l'URL n'a ni schéma ni
        host). PropertyViewSet.get_serializer_context() est bien câblé
        (déjà en place), ce test verrouille ce contrat pour de bon : l'URL
        sérialisée doit toujours être absolue."""
        self.client.force_authenticate(user=self.owner)
        response = self.client.post(self.url, {"video": _make_video_file()}, format="multipart")
        video_url = response.data["video"]
        self.assertTrue(
            video_url.startswith("http://") or video_url.startswith("https://"),
            f"l'URL vidéo doit être absolue, reçu : {video_url!r}",
        )
        self.assertIn("/media/", video_url)

    def test_video_file_supports_http_range_requests(self):
        """Correction (audit vidéo) — CAUSE EXACTE du bug "vidéo publiée mais
        illisible" : ni django.views.static.serve ni django.http.FileResponse
        ne gèrent le header Range (vérifié dans le code source de Django) —
        le serveur renvoyait toujours 200 + le fichier entier, quelle que
        soit la plage demandée. Une vidéo réelle filmée par un téléphone
        place presque toujours l'atome MP4 "moov" à la FIN du fichier ;
        video_player (ExoPlayer) a besoin d'une requête Range pour l'y
        atteindre avant de pouvoir initialiser la lecture — sans ça,
        l'initialisation échouait silencieusement. Corrigé par
        config/media_views.py::serve_media.

        Appelle directement serve_media (via RequestFactory) plutôt que de
        passer par self.client.get("/media/...") : Django force DEBUG=False
        pour toute la durée des tests (comportement documenté du test
        runner), donc le urlpattern conditionnel `if settings.DEBUG:` de
        config/urls.py n'existe simplement pas dans ce contexte — ce test
        vise directement la fonction qui contient la logique à vérifier,
        exactement le même code que celui réellement monté en développement/
        LAN (voir config/urls.py)."""
        self.client.force_authenticate(user=self.owner)
        self.client.post(self.url, {"video": _make_video_file()}, format="multipart")
        self.property.refresh_from_db()
        file_size = self.property.video.size
        relative_path = self.property.video.name

        factory = RequestFactory()

        # Sans Range : comportement inchangé (200, fichier entier). Réponses
        # streamées : un vrai serveur WSGI les consomme entièrement en les
        # écrivant sur le socket (ce qui referme le fichier au passage) — ici
        # il faut le faire explicitement, sans quoi le fichier reste ouvert
        # et le tearDown() de ce test (qui le supprime) échoue sous Windows
        # avec un PermissionError (fichier verrouillé par un handle encore
        # ouvert).
        full_request = factory.get(f"/media/{relative_path}")
        full_response = serve_media(
            full_request, relative_path, document_root=settings.MEDIA_ROOT
        )
        self.assertEqual(full_response.status_code, status.HTTP_200_OK)
        self.assertEqual(full_response.headers["Content-Type"], "video/mp4")
        full_response.close()

        # Avec Range : c'est exactement ce qu'un lecteur vidéo réseau envoie
        # pour sauter directement à une partie du fichier (ex. la fin, pour
        # lire l'atome "moov" d'un MP4 non fast-start).
        range_request = factory.get(f"/media/{relative_path}", HTTP_RANGE="bytes=0-9")
        range_response = serve_media(
            range_request, relative_path, document_root=settings.MEDIA_ROOT
        )
        self.assertEqual(range_response.status_code, 206)
        self.assertEqual(range_response.headers["Content-Range"], f"bytes 0-9/{file_size}")
        self.assertEqual(range_response.headers["Content-Length"], "10")
        self.assertEqual(range_response.headers["Accept-Ranges"], "bytes")
        self.assertEqual(range_response.headers["Content-Type"], "video/mp4")
        b"".join(range_response.streaming_content)

        # Une requête Range hors bornes doit être rejetée proprement (416),
        # jamais planter ni renvoyer un contenu incohérent.
        out_of_bounds_request = factory.get(
            f"/media/{relative_path}", HTTP_RANGE=f"bytes={file_size + 100}-{file_size + 200}"
        )
        out_of_bounds = serve_media(
            out_of_bounds_request, relative_path, document_root=settings.MEDIA_ROOT
        )
        self.assertEqual(out_of_bounds.status_code, 416)

    # 2. Le propriétaire peut remplacer sa vidéo.
    def test_owner_can_replace_video(self):
        self.client.force_authenticate(user=self.owner)
        self.client.post(self.url, {"video": _make_video_file("first.mp4")}, format="multipart")
        response = self.client.post(self.url, {"video": _make_video_file("second.mp4")}, format="multipart")
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.property.refresh_from_db()
        self.assertIn("second", self.property.video.name)

    # 3. Le propriétaire peut supprimer sa vidéo.
    def test_owner_can_delete_video(self):
        self.client.force_authenticate(user=self.owner)
        self.client.post(self.url, {"video": _make_video_file()}, format="multipart")
        response = self.client.delete(self.url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIsNone(response.data["video"])
        self.property.refresh_from_db()
        self.assertFalse(bool(self.property.video))

    # 4. Un autre agent ne peut pas modifier la vidéo (403).
    def test_other_agent_cannot_upload_video(self):
        self.client.force_authenticate(user=self.other_agent)
        response = self.client.post(self.url, {"video": _make_video_file()}, format="multipart")
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
        self.property.refresh_from_db()
        self.assertFalse(bool(self.property.video))

    # 5. Un autre bailleur ne peut pas modifier la vidéo (403).
    def test_other_bailleur_cannot_upload_video(self):
        bailleur_property = _make_property(self.bailleur, "Bien du bailleur")
        self.client.force_authenticate(user=self.other_agent)
        response = self.client.post(
            f"/api/properties/{bailleur_property.id}/video/",
            {"video": _make_video_file()},
            format="multipart",
        )
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    # 6. Un client ne peut pas modifier la vidéo (403).
    def test_client_cannot_upload_video(self):
        self.client.force_authenticate(user=self.client_user)
        response = self.client.post(self.url, {"video": _make_video_file()}, format="multipart")
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    # 7. Vidéo > 50 Mo → 400.
    def test_video_over_50mo_rejected(self):
        self.client.force_authenticate(user=self.owner)
        oversized = _make_video_file(extra_padding=51 * 1024 * 1024)
        response = self.client.post(self.url, {"video": oversized}, format="multipart")
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.property.refresh_from_db()
        self.assertFalse(bool(self.property.video))

    # 8. Mauvais format → 400.
    def test_wrong_format_rejected(self):
        self.client.force_authenticate(user=self.owner)
        bad_file = SimpleUploadedFile("clip.avi", b"not a real video", content_type="video/avi")
        response = self.client.post(self.url, {"video": bad_file}, format="multipart")
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    # 9. Une seule vidéo par annonce : le second envoi remplace, ne s'ajoute pas.
    def test_only_one_video_enforced(self):
        self.client.force_authenticate(user=self.owner)
        self.client.post(self.url, {"video": _make_video_file("first.mp4")}, format="multipart")
        response = self.client.post(self.url, {"video": _make_video_file("second.mp4")}, format="multipart")
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        # Le champ sérialisé est une seule URL (string), jamais une liste.
        self.assertIsInstance(response.data["video"], str)

    # 10. Le remplacement nettoie l'ancien fichier du stockage.
    def test_replacement_cleans_up_old_file(self):
        self.client.force_authenticate(user=self.owner)
        self.client.post(self.url, {"video": _make_video_file("first.mp4")}, format="multipart")
        self.property.refresh_from_db()
        old_path = self.property.video.name
        self.assertTrue(default_storage.exists(old_path))

        self.client.post(self.url, {"video": _make_video_file("second.mp4")}, format="multipart")
        self.assertFalse(default_storage.exists(old_path))

    # 11. La suppression de l'annonce nettoie le fichier vidéo.
    def test_property_deletion_cleans_up_video(self):
        self.client.force_authenticate(user=self.owner)
        self.client.post(self.url, {"video": _make_video_file()}, format="multipart")
        self.property.refresh_from_db()
        video_path = self.property.video.name

        response = self.client.delete(f"/api/properties/{self.property.id}/")
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)
        self.assertFalse(default_storage.exists(video_path))

    # 12. Une annonce sans vidéo reste parfaitement valide.
    def test_property_without_video_remains_valid(self):
        self.client.force_authenticate(user=self.owner)
        response = self.client.get(f"/api/properties/{self.property.id}/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertIsNone(response.data["video"])

    # 13. Une annonce occupée conserve sa vidéo.
    def test_occupied_property_keeps_its_video(self):
        self.client.force_authenticate(user=self.owner)
        self.client.post(self.url, {"video": _make_video_file()}, format="multipart")
        response = self.client.post(
            f"/api/properties/{self.property.id}/status/", {"status": "occupee"}, format="json"
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.property.refresh_from_db()
        self.assertTrue(bool(self.property.video))

    # 14. Une annonce vendue conserve sa vidéo.
    def test_sold_property_keeps_its_video(self):
        vente_property = Property.objects.create(
            title="Villa avec vidéo", category="Villa", type="logement",
            transaction_type="vente", price=50000000, commune="X", district="Y",
            agent=self.owner,
        )
        self.client.force_authenticate(user=self.owner)
        self.client.post(
            f"/api/properties/{vente_property.id}/video/", {"video": _make_video_file()}, format="multipart"
        )
        response = self.client.post(
            f"/api/properties/{vente_property.id}/status/", {"status": "vendue"}, format="json"
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        vente_property.refresh_from_db()
        self.assertTrue(bool(vente_property.video))
        vente_property.video.delete(save=False)

    # Validation additionnelle explicitement demandée : la durée réelle du
    # fichier MP4 est bien lue (mvhd) et rejetée au-delà de 60 s — pas
    # seulement la taille/le format.
    def test_video_over_60_seconds_rejected(self):
        self.client.force_authenticate(user=self.owner)
        too_long = _make_video_file(duration_seconds=61)
        response = self.client.post(self.url, {"video": too_long}, format="multipart")
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
