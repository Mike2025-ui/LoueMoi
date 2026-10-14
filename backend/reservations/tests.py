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

    def test_bailleur_can_see_reservations_on_own_property(self):
        """Régression corrigée dans cette mission : get_queryset() ne
        branchait que sur ROLE_AGENT, un bailleur ne voyait jamais les
        réservations faites sur ses propres biens."""
        bailleur = User.objects.create_user(
            phone="+2250722222204", password="secret123", first_name="Bl", last_name="B",
            role=User.ROLE_BAILLEUR,
        )
        property_bailleur = Property.objects.create(
            title="Bien bailleur", category="Studio", type="logement",
            transaction_type="location", price=100000, commune="X", district="Y",
            agent=bailleur,
        )
        reservation = Reservation.objects.create(
            property=property_bailleur, user=self.client_user,
            rent=100000, deposit=0, advance=0, status="enCours",
        )

        self.client.force_authenticate(user=bailleur)
        response = self.client.get("/api/reservations/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        ids = [r["id"] for r in response.data["results"]]
        self.assertIn(reservation.id, ids)

    def test_owner_sees_reserving_client_contact_info(self):
        self.client.force_authenticate(user=self.agent_a)
        response = self.client.get("/api/reservations/")
        entry = next(r for r in response.data["results"] if r["id"] == self.reservation.id)
        self.assertEqual(entry["client"]["id"], self.client_user.id)
        self.assertEqual(entry["client"]["first_name"], "C")
        self.assertIn("phone", entry["client"])


class ReservationDoesNotAutoOccupyPropertyTests(APITestCase):
    """CORRECTION MÉTIER MAJEURE (section 5) : une réservation ne rend plus
    automatiquement une propriété "occupee". Seul le propriétaire décide,
    via l'action dédiée PropertyViewSet.mark_status."""

    def setUp(self):
        self.agent = User.objects.create_user(
            phone="+2250722222301", password="secret123", first_name="A", last_name="A",
            role=User.ROLE_AGENT,
        )
        self.other_agent = User.objects.create_user(
            phone="+2250722222304", password="secret123", first_name="A2", last_name="A2",
            role=User.ROLE_AGENT,
        )
        self.first_client = User.objects.create_user(
            phone="+2250722222302", password="secret123", first_name="C1", last_name="L",
            role=User.ROLE_CLIENT,
        )
        self.second_client = User.objects.create_user(
            phone="+2250722222303", password="secret123", first_name="C2", last_name="L",
            role=User.ROLE_CLIENT,
        )
        self.property_obj = Property.objects.create(
            title="Bien unique", category="Studio", type="logement", transaction_type="location",
            price=100000, commune="X", district="Y", agent=self.agent,
        )

    def test_reservation_does_not_change_property_status(self):
        self.client.force_authenticate(user=self.first_client)
        response = self.client.post(
            "/api/reservations/",
            {"property_id": self.property_obj.id, "rent": 100000, "deposit": 0, "advance": 0},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.property_obj.refresh_from_db()
        self.assertEqual(self.property_obj.status, "disponible")

    def test_multiple_reservations_allowed_while_property_stays_disponible(self):
        """La propriété ne devenant plus "occupee" automatiquement, rien
        n'empêche plusieurs clients de réserver le même bien avant que le
        propriétaire ne le marque occupé lui-même — comportement voulu."""
        self.client.force_authenticate(user=self.first_client)
        first_response = self.client.post(
            "/api/reservations/",
            {"property_id": self.property_obj.id, "rent": 100000, "deposit": 0, "advance": 0},
            format="json",
        )
        self.assertEqual(first_response.status_code, status.HTTP_201_CREATED)

        self.client.force_authenticate(user=self.second_client)
        second_response = self.client.post(
            "/api/reservations/",
            {"property_id": self.property_obj.id, "rent": 100000, "deposit": 0, "advance": 0},
            format="json",
        )
        self.assertEqual(second_response.status_code, status.HTTP_201_CREATED)

    def test_owner_can_manually_mark_property_occupied(self):
        self.client.force_authenticate(user=self.agent)
        response = self.client.post(
            f"/api/properties/{self.property_obj.id}/status/", {"status": "occupee"}, format="json"
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.property_obj.refresh_from_db()
        self.assertEqual(self.property_obj.status, "occupee")

    def test_owner_can_manually_mark_property_disponible_again(self):
        self.property_obj.status = "occupee"
        self.property_obj.save(update_fields=["status"])
        self.client.force_authenticate(user=self.agent)
        response = self.client.post(
            f"/api/properties/{self.property_obj.id}/status/",
            {"status": "disponible"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.property_obj.refresh_from_db()
        self.assertEqual(self.property_obj.status, "disponible")

    def test_occupied_property_still_blocks_new_reservations(self):
        """Une fois marquée occupée (manuellement), la validation existante
        du serializer continue de refuser toute nouvelle réservation."""
        self.property_obj.status = "occupee"
        self.property_obj.save(update_fields=["status"])
        self.client.force_authenticate(user=self.first_client)
        response = self.client.post(
            "/api/reservations/",
            {"property_id": self.property_obj.id, "rent": 100000, "deposit": 0, "advance": 0},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_another_agent_cannot_mark_status(self):
        self.client.force_authenticate(user=self.other_agent)
        response = self.client.post(
            f"/api/properties/{self.property_obj.id}/status/", {"status": "occupee"}, format="json"
        )
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
        self.property_obj.refresh_from_db()
        self.assertEqual(self.property_obj.status, "disponible")

    def test_client_cannot_mark_status(self):
        self.client.force_authenticate(user=self.first_client)
        response = self.client.post(
            f"/api/properties/{self.property_obj.id}/status/", {"status": "occupee"}, format="json"
        )
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_mark_status_rejects_invalid_value(self):
        self.client.force_authenticate(user=self.agent)
        response = self.client.post(
            f"/api/properties/{self.property_obj.id}/status/", {"status": "disabled"}, format="json"
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.property_obj.refresh_from_db()
        self.assertEqual(self.property_obj.status, "disponible")


class ReservationNotificationActorTests(APITestCase):
    """Section 6 : l'acteur d'une action ne reçoit jamais sa propre
    notification pour cette action."""

    def setUp(self):
        from notifications.models import Notification

        self.Notification = Notification
        self.agent = User.objects.create_user(
            phone="+2250722222401", password="secret123", first_name="A", last_name="A",
            role=User.ROLE_AGENT,
        )
        self.client_user = User.objects.create_user(
            phone="+2250722222402", password="secret123", first_name="C", last_name="L",
            role=User.ROLE_CLIENT,
        )
        self.property_obj = Property.objects.create(
            title="Bien", category="Studio", type="logement", transaction_type="location",
            price=100000, commune="X", district="Y", agent=self.agent,
        )

    def test_reserving_client_does_not_receive_a_notification(self):
        self.client.force_authenticate(user=self.client_user)
        with self.captureOnCommitCallbacks(execute=True):
            response = self.client.post(
                "/api/reservations/",
                {"property_id": self.property_obj.id, "rent": 100000, "deposit": 0, "advance": 0},
                format="json",
            )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertFalse(
            self.Notification.objects.filter(recipient=self.client_user).exists()
        )

    def test_owner_receives_new_reservation_notification(self):
        self.client.force_authenticate(user=self.client_user)
        with self.captureOnCommitCallbacks(execute=True):
            self.client.post(
                "/api/reservations/",
                {"property_id": self.property_obj.id, "rent": 100000, "deposit": 0, "advance": 0},
                format="json",
            )
        self.assertTrue(
            self.Notification.objects.filter(
                recipient=self.agent, type=self.Notification.TYPE_NEW_RESERVATION
            ).exists()
        )

    def test_owner_cannot_cancel_client_reservation(self):
        """Correction (audit de régression) : `cancel` n'imposait auparavant
        aucune restriction de propriétaire au-delà du queryset (qui inclut,
        pour un agent/bailleur, les réservations faites sur SES biens — afin
        qu'il puisse voir qui a réservé) — un propriétaire pouvait donc
        annuler la réservation de son client depuis ce même endpoint, ce que
        la règle métier interdit explicitement (voir
        ReservationCancelTests pour la couverture complète de ce correctif).
        Ce test remplace l'ancien test_owner_cancelling_does_not_notify_self,
        qui vérifiait par erreur l'exclusion d'auto-notification sur un
        appel qui n'aurait jamais dû être autorisé en premier lieu."""
        reservation = Reservation.objects.create(
            property=self.property_obj, user=self.client_user,
            rent=100000, deposit=0, advance=0, status="enCours",
        )
        self.client.force_authenticate(user=self.agent)
        response = self.client.post(f"/api/reservations/{reservation.id}/cancel/")
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
        reservation.refresh_from_db()
        self.assertEqual(reservation.status, "enCours")
        self.assertFalse(
            self.Notification.objects.filter(
                type=self.Notification.TYPE_RESERVATION_CANCELLED
            ).exists()
        )

    def test_client_cancelling_does_not_notify_self(self):
        reservation = Reservation.objects.create(
            property=self.property_obj, user=self.client_user,
            rent=100000, deposit=0, advance=0, status="enCours",
        )
        self.client.force_authenticate(user=self.client_user)
        with self.captureOnCommitCallbacks(execute=True):
            self.client.post(f"/api/reservations/{reservation.id}/cancel/")
        self.assertFalse(
            self.Notification.objects.filter(
                recipient=self.client_user, type=self.Notification.TYPE_RESERVATION_CANCELLED
            ).exists()
        )
        self.assertTrue(
            self.Notification.objects.filter(
                recipient=self.agent, type=self.Notification.TYPE_RESERVATION_CANCELLED
            ).exists()
        )


class ReservationConversationTests(APITestCase):
    """POST /api/reservations/{id}/conversation/ — bouton "Discuter" côté
    carte de réservation : le propriétaire du bien peut ouvrir une
    conversation avec le client qui a réservé, même si ce dernier n'a pas le
    rôle agent (Conversation.agent n'est normalement ouvert qu'aux agents
    via le endpoint public de création)."""

    def setUp(self):
        from messaging.models import Conversation

        self.Conversation = Conversation
        self.bailleur = User.objects.create_user(
            phone="+2250722222501", password="secret123", first_name="Bl", last_name="B",
            role=User.ROLE_BAILLEUR,
        )
        self.client_user = User.objects.create_user(
            phone="+2250722222502", password="secret123", first_name="C", last_name="L",
            role=User.ROLE_CLIENT,
        )
        self.outsider = User.objects.create_user(
            phone="+2250722222503", password="secret123", first_name="O", last_name="U",
            role=User.ROLE_AGENT,
        )
        self.property_obj = Property.objects.create(
            title="Bien", category="Studio", type="logement", transaction_type="location",
            price=100000, commune="X", district="Y", agent=self.bailleur,
        )
        self.reservation = Reservation.objects.create(
            property=self.property_obj, user=self.client_user,
            rent=100000, deposit=0, advance=0, status="enCours",
        )

    def test_owner_can_open_conversation_with_non_agent_client(self):
        self.client.force_authenticate(user=self.bailleur)
        response = self.client.post(f"/api/reservations/{self.reservation.id}/conversation/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["client"], self.client_user.id)
        self.assertEqual(response.data["agent"], self.bailleur.id)

    def test_calling_twice_reuses_the_same_conversation(self):
        self.client.force_authenticate(user=self.bailleur)
        first = self.client.post(f"/api/reservations/{self.reservation.id}/conversation/")
        second = self.client.post(f"/api/reservations/{self.reservation.id}/conversation/")
        self.assertEqual(first.data["id"], second.data["id"])
        self.assertEqual(self.Conversation.objects.count(), 1)

    def test_client_cannot_use_this_endpoint(self):
        self.client.force_authenticate(user=self.client_user)
        response = self.client.post(f"/api/reservations/{self.reservation.id}/conversation/")
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_unrelated_agent_cannot_use_this_endpoint(self):
        self.client.force_authenticate(user=self.outsider)
        response = self.client.post(f"/api/reservations/{self.reservation.id}/conversation/")
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)


class ReservationCompleteTests(APITestCase):
    """POST /api/reservations/{id}/complete/ — Phase 2 de la mission de
    finalisation : seul chemin API (hors Django Admin) pour faire passer une
    réservation à "accomplie". Property.status ne doit jamais bouger à cette
    occasion (voir test_completing_never_touches_property_status) — c'est
    la distinction centrale de toute la mission (Reservation.status et
    Property.status sont deux états indépendants)."""

    def setUp(self):
        self.bailleur = User.objects.create_user(
            phone="+2250722223001", password="secret123", first_name="Bl", last_name="B",
            role=User.ROLE_BAILLEUR,
        )
        self.client_user = User.objects.create_user(
            phone="+2250722223002", password="secret123", first_name="C", last_name="L",
            role=User.ROLE_CLIENT,
        )
        self.outsider = User.objects.create_user(
            phone="+2250722223003", password="secret123", first_name="O", last_name="U",
            role=User.ROLE_AGENT,
        )
        self.property_obj = Property.objects.create(
            title="Bien", category="Studio", type="logement", transaction_type="location",
            price=100000, commune="X", district="Y", agent=self.bailleur,
        )
        self.reservation = Reservation.objects.create(
            property=self.property_obj, user=self.client_user,
            rent=100000, deposit=0, advance=0, status="enCours",
        )

    def test_owner_can_complete_the_reservation(self):
        self.client.force_authenticate(user=self.bailleur)
        response = self.client.post(f"/api/reservations/{self.reservation.id}/complete/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["status"], "accomplie")
        self.reservation.refresh_from_db()
        self.assertEqual(self.reservation.status, "accomplie")

    def test_completing_never_touches_property_status(self):
        """Le coeur de la Partie 4 de la mission : Reservation.status et
        Property.status restent deux états totalement indépendants."""
        self.client.force_authenticate(user=self.bailleur)
        self.client.post(f"/api/reservations/{self.reservation.id}/complete/")
        self.property_obj.refresh_from_db()
        self.assertEqual(self.property_obj.status, "disponible")

    def test_owner_receives_no_notification_but_client_does(self):
        from notifications.models import Notification

        self.client.force_authenticate(user=self.bailleur)
        with self.captureOnCommitCallbacks(execute=True):
            self.client.post(f"/api/reservations/{self.reservation.id}/complete/")

        self.assertTrue(
            Notification.objects.filter(
                recipient=self.client_user, type=Notification.TYPE_RESERVATION_CONFIRMED
            ).exists()
        )
        self.assertFalse(
            Notification.objects.filter(
                recipient=self.bailleur, type=Notification.TYPE_RESERVATION_CONFIRMED
            ).exists()
        )

    def test_client_cannot_complete_their_own_reservation(self):
        self.client.force_authenticate(user=self.client_user)
        response = self.client.post(f"/api/reservations/{self.reservation.id}/complete/")
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
        self.reservation.refresh_from_db()
        self.assertEqual(self.reservation.status, "enCours")

    def test_unrelated_agent_cannot_complete_it(self):
        self.client.force_authenticate(user=self.outsider)
        response = self.client.post(f"/api/reservations/{self.reservation.id}/complete/")
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_cancelled_reservation_cannot_be_completed(self):
        self.reservation.status = "annulee"
        self.reservation.save(update_fields=["status"])
        self.client.force_authenticate(user=self.bailleur)
        response = self.client.post(f"/api/reservations/{self.reservation.id}/complete/")
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.reservation.refresh_from_db()
        self.assertEqual(self.reservation.status, "annulee")

    def test_completing_twice_is_idempotent_and_notifies_only_once(self):
        from notifications.models import Notification

        self.client.force_authenticate(user=self.bailleur)
        with self.captureOnCommitCallbacks(execute=True):
            first = self.client.post(f"/api/reservations/{self.reservation.id}/complete/")
        with self.captureOnCommitCallbacks(execute=True):
            second = self.client.post(f"/api/reservations/{self.reservation.id}/complete/")

        self.assertEqual(first.status_code, status.HTTP_200_OK)
        self.assertEqual(second.status_code, status.HTTP_200_OK)
        self.assertEqual(
            Notification.objects.filter(
                recipient=self.client_user, type=Notification.TYPE_RESERVATION_CONFIRMED
            ).count(),
            1,
        )


class ReservationCancelTests(APITestCase):
    """Correction (audit de régression — bouton "Annuler") : `cancel`
    n'imposait auparavant aucune restriction de propriétaire ni de
    transition de statut — un propriétaire pouvait annuler la réservation
    d'un client, et une réservation "accomplie" ou déjà "annulee" pouvait
    être "annulée" de nouveau sans erreur (renvoyant les notifications à
    chaque appel). Cette classe couvre le correctif complet."""

    def setUp(self):
        self.bailleur = User.objects.create_user(
            phone="+2250722224001", password="secret123", first_name="Bl", last_name="B",
            role=User.ROLE_BAILLEUR,
        )
        self.client_user = User.objects.create_user(
            phone="+2250722224002", password="secret123", first_name="C", last_name="L",
            role=User.ROLE_CLIENT,
        )
        self.other_client = User.objects.create_user(
            phone="+2250722224003", password="secret123", first_name="C2", last_name="L2",
            role=User.ROLE_CLIENT,
        )
        self.property_obj = Property.objects.create(
            title="Bien", category="Studio", type="logement", transaction_type="location",
            price=100000, commune="X", district="Y", agent=self.bailleur,
        )
        self.reservation = Reservation.objects.create(
            property=self.property_obj, user=self.client_user,
            rent=100000, deposit=0, advance=0, status="enCours",
        )

    def test_client_can_cancel_own_reservation(self):
        self.client.force_authenticate(user=self.client_user)
        response = self.client.post(f"/api/reservations/{self.reservation.id}/cancel/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["status"], "annulee")
        self.reservation.refresh_from_db()
        self.assertEqual(self.reservation.status, "annulee")

    def test_cancelling_never_touches_property_status(self):
        self.client.force_authenticate(user=self.client_user)
        self.client.post(f"/api/reservations/{self.reservation.id}/cancel/")
        self.property_obj.refresh_from_db()
        self.assertEqual(self.property_obj.status, "disponible")

    def test_unrelated_client_cannot_cancel_another_clients_reservation(self):
        self.client.force_authenticate(user=self.other_client)
        response = self.client.post(f"/api/reservations/{self.reservation.id}/cancel/")
        # Ce client n'apparaît même pas dans le queryset de cette réservation
        # (ni user=lui-même, ni property__agent=lui-même) : get_object() lève
        # donc un 404, pas un 403 — même comportement que les autres actions
        # de ce ViewSet pour un tiers totalement étranger à la réservation.
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)
        self.reservation.refresh_from_db()
        self.assertEqual(self.reservation.status, "enCours")

    def test_completed_reservation_cannot_be_cancelled(self):
        self.reservation.status = "accomplie"
        self.reservation.save(update_fields=["status"])
        self.client.force_authenticate(user=self.client_user)
        response = self.client.post(f"/api/reservations/{self.reservation.id}/cancel/")
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.reservation.refresh_from_db()
        self.assertEqual(self.reservation.status, "accomplie")

    def test_already_cancelled_reservation_cannot_be_cancelled_again(self):
        self.reservation.status = "annulee"
        self.reservation.save(update_fields=["status"])
        self.client.force_authenticate(user=self.client_user)
        response = self.client.post(f"/api/reservations/{self.reservation.id}/cancel/")
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_repeated_cancel_attempts_never_duplicate_notifications(self):
        """Avant correctif : chaque appel à `cancel`, y compris sur une
        réservation déjà annulée, redéclenchait les deux notifications
        d'annulation — un double-clic (ou une requête rejouée) pouvait donc
        spammer indéfiniment le propriétaire."""
        from notifications.models import Notification

        self.client.force_authenticate(user=self.client_user)
        with self.captureOnCommitCallbacks(execute=True):
            first = self.client.post(f"/api/reservations/{self.reservation.id}/cancel/")
        with self.captureOnCommitCallbacks(execute=True):
            second = self.client.post(f"/api/reservations/{self.reservation.id}/cancel/")

        self.assertEqual(first.status_code, status.HTTP_200_OK)
        self.assertEqual(second.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(
            Notification.objects.filter(
                recipient=self.bailleur, type=Notification.TYPE_RESERVATION_CANCELLED
            ).count(),
            1,
        )
