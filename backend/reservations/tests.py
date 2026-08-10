from django.contrib.auth import get_user_model
from rest_framework import status
from rest_framework.test import APITestCase

from properties.models import Property

from .models import Reservation

User = get_user_model()


class ReservationVisibilityTests(APITestCase):
    """Tests 10, 11 (voir cahier des charges section 30)."""

    def setUp(self):
        self.client_user = User.objects.create_user(
            phone="+2250722222201", password="secret123", first_name="C", last_name="L",
            role=User.ROLE_CLIENT,
        )
        self.agent_a = User.objects.create_user(
            phone="+2250722222202", password="secret123", first_name="A", last_name="A",
            role=User.ROLE_AGENT,
        )
        self.agent_b = User.objects.create_user(
            phone="+2250722222203", password="secret123", first_name="B", last_name="B",
            role=User.ROLE_AGENT,
        )
        self.property_a = Property.objects.create(
            title="Bien A", category="Studio", type="logement", transaction_type="location",
            price=100000, commune="X", district="Y", agent=self.agent_a,
        )
        self.reservation = Reservation.objects.create(
            property=self.property_a, user=self.client_user,
            rent=100000, deposit=0, advance=0, status="enCours",
        )

    def test_agent_can_see_reservations_on_own_property(self):
        self.client.force_authenticate(user=self.agent_a)
        response = self.client.get("/api/reservations/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        ids = [r["id"] for r in response.data["results"]]
        self.assertIn(self.reservation.id, ids)

    def test_agent_cannot_see_reservations_of_another_agent(self):
        self.client.force_authenticate(user=self.agent_b)
        response = self.client.get("/api/reservations/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        ids = [r["id"] for r in response.data["results"]]
        self.assertNotIn(self.reservation.id, ids)


class OccupiedPropertyNotReservableTests(APITestCase):
    """Test 12 : une propriété "occupee" (déjà réservée) ne doit plus être
    réservable — Django reste la source de vérité, jamais le client."""

    def test_occupied_property_cannot_be_reserved_again(self):
        agent = User.objects.create_user(
            phone="+2250722222301", password="secret123", first_name="A", last_name="A",
            role=User.ROLE_AGENT,
        )
        first_client = User.objects.create_user(
            phone="+2250722222302", password="secret123", first_name="C1", last_name="L",
            role=User.ROLE_CLIENT,
        )
        second_client = User.objects.create_user(
            phone="+2250722222303", password="secret123", first_name="C2", last_name="L",
            role=User.ROLE_CLIENT,
        )
        property_obj = Property.objects.create(
            title="Bien unique", category="Studio", type="logement", transaction_type="location",
            price=100000, commune="X", district="Y", agent=agent,
        )

        self.client.force_authenticate(user=first_client)
        first_response = self.client.post(
            "/api/reservations/",
            {"property_id": property_obj.id, "rent": 100000, "deposit": 0, "advance": 0},
            format="json",
        )
        self.assertEqual(first_response.status_code, status.HTTP_201_CREATED)
        property_obj.refresh_from_db()
        self.assertEqual(property_obj.status, "occupee")

        self.client.force_authenticate(user=second_client)
        second_response = self.client.post(
            "/api/reservations/",
            {"property_id": property_obj.id, "rent": 100000, "deposit": 0, "advance": 0},
            format="json",
        )
        self.assertEqual(second_response.status_code, status.HTTP_400_BAD_REQUEST)
