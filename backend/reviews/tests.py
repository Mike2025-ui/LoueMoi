from django.contrib.auth import get_user_model
from rest_framework import status
from rest_framework.test import APITestCase

from properties.models import Property

from .models import Review

User = get_user_model()


class ReviewEligibilityTests(APITestCase):
    """Règle métier : tout le monde peut donner son avis pour apprécier une pub
    et donner des étoiles. Seul le propriétaire de l'annonce ne peut pas
    noter son propre bien."""

    def setUp(self):
        self.agent = User.objects.create_user(
            phone="+2250733333301", password="secret123", first_name="A", last_name="Agent",
            role=User.ROLE_AGENT,
        )
        self.reviewer = User.objects.create_user(
            phone="+2250733333302", password="secret123", first_name="C", last_name="Client",
            role=User.ROLE_CLIENT,
        )
        self.other_user = User.objects.create_user(
            phone="+2250733333303", password="secret123", first_name="O", last_name="Other",
            role=User.ROLE_CLIENT,
        )
        self.property_obj = Property.objects.create(
            title="Bien testé", category="Studio", type="logement", transaction_type="location",
            price=100000, commune="X", district="Y", agent=self.agent,
        )
        self.url = f"/api/properties/{self.property_obj.id}/reviews/"

    def _post_review(self, user, rating=5, comment="Très bien."):
        self.client.force_authenticate(user=user)
        return self.client.post(self.url, {"rating": rating, "comment": comment}, format="json")

    def test_anyone_authenticated_can_post_review_without_reservation(self):
        # N'importe quel utilisateur connecté peut laisser un avis sans réservation
        response = self._post_review(self.reviewer, rating=4.5, comment="Superbe maison !")
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(Review.objects.filter(property=self.property_obj).count(), 1)
        review = Review.objects.get(property=self.property_obj)
        self.assertEqual(float(review.rating), 4.5)
        self.assertEqual(review.comment, "Superbe maison !")

    def test_multiple_users_can_post_reviews_and_give_stars(self):
        self._post_review(self.reviewer, rating=5, comment="Génial")
        self._post_review(self.other_user, rating=3, comment="Moyen")
        self.assertEqual(Review.objects.filter(property=self.property_obj).count(), 2)

    def test_owner_cannot_review_own_property(self):
        # Le propriétaire du bien ne peut pas noter son propre bien
        response = self._post_review(self.agent, rating=5, comment="Mon propre bien")
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(Review.objects.filter(property=self.property_obj).count(), 0)

    def test_unauthenticated_cannot_post_review(self):
        self.client.force_authenticate(user=None)
        response = self.client.post(self.url, {"rating": 5, "comment": "Anonyme"}, format="json")
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_reading_reviews_never_requires_authentication(self):
        Review.objects.create(
            property=self.property_obj, user=self.reviewer, rating=4, comment="Bien.",
        )
        self.client.force_authenticate(user=None)
        response = self.client.get(self.url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(len(response.data["results"]), 1)

    def test_user_cannot_post_duplicate_reviews(self):
        # Un utilisateur ne peut pas spammer d'avis sur la même annonce
        response1 = self._post_review(self.reviewer, rating=5, comment="Premier avis.")
        self.assertEqual(response1.status_code, status.HTTP_201_CREATED)
        response2 = self._post_review(self.reviewer, rating=4, comment="Deuxième avis.")
        self.assertEqual(response2.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("déjà laissé un avis", str(response2.data))
