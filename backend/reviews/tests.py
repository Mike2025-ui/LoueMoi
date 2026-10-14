from django.contrib.auth import get_user_model
from rest_framework import status
from rest_framework.test import APITestCase

from properties.models import Property
from reservations.models import Reservation

from .models import Review

User = get_user_model()


class ReviewEligibilityTests(APITestCase):
    """Correction (audit de régression) : un avis n'est autorisé que si son
    auteur a une réservation "accomplie" sur le bien concerné — auparavant
    n'importe quel compte authentifié pouvait noter n'importe quelle
    propriété, sans jamais l'avoir réservée."""

    def setUp(self):
        self.agent = User.objects.create_user(
            phone="+2250733333301", password="secret123", first_name="A", last_name="Agent",
            role=User.ROLE_AGENT,
        )
        self.reviewer = User.objects.create_user(
            phone="+2250733333302", password="secret123", first_name="C", last_name="Client",
            role=User.ROLE_CLIENT,
        )
        self.property_obj = Property.objects.create(
            title="Bien testé", category="Studio", type="logement", transaction_type="location",
            price=100000, commune="X", district="Y", agent=self.agent,
        )
        self.url = f"/api/properties/{self.property_obj.id}/reviews/"

    def _post_review(self, user):
        self.client.force_authenticate(user=user)
        return self.client.post(self.url, {"rating": 5, "comment": "Très bien."}, format="json")

    def test_review_allowed_after_completed_reservation(self):
        Reservation.objects.create(
            property=self.property_obj, user=self.reviewer,
            rent=100000, deposit=0, advance=0, status="accomplie",
        )
        response = self._post_review(self.reviewer)
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(Review.objects.filter(property=self.property_obj).count(), 1)

    def test_review_rejected_without_any_reservation(self):
        response = self._post_review(self.reviewer)
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
        self.assertEqual(Review.objects.filter(property=self.property_obj).count(), 0)

    def test_review_rejected_with_reservation_still_encours(self):
        Reservation.objects.create(
            property=self.property_obj, user=self.reviewer,
            rent=100000, deposit=0, advance=0, status="enCours",
        )
        response = self._post_review(self.reviewer)
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_review_rejected_with_cancelled_reservation(self):
        Reservation.objects.create(
            property=self.property_obj, user=self.reviewer,
            rent=100000, deposit=0, advance=0, status="annulee",
        )
        response = self._post_review(self.reviewer)
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_review_rejected_with_completed_reservation_on_another_property(self):
        other_property = Property.objects.create(
            title="Autre bien", category="Studio", type="logement", transaction_type="location",
            price=100000, commune="X", district="Y", agent=self.agent,
        )
        Reservation.objects.create(
            property=other_property, user=self.reviewer,
            rent=100000, deposit=0, advance=0, status="accomplie",
        )
        response = self._post_review(self.reviewer)
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_reading_reviews_never_requires_a_reservation(self):
        Review.objects.create(
            property=self.property_obj, user=self.reviewer, rating=4, comment="Bien.",
        )
        self.client.force_authenticate(user=None)
        response = self.client.get(self.url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data["results"]), 1)
