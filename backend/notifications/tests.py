from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.test import TestCase
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from properties.models import Property
from reservations.models import Reservation
from reviews.models import Review

from .models import DeviceToken, Notification
from .services import NotificationService

User = get_user_model()


def _make_agent(phone):
    return User.objects.create_user(
        phone=phone, password="secret123", first_name="Agent", last_name=phone,
        role=User.ROLE_AGENT,
    )


def _make_bailleur(phone):
    return User.objects.create_user(
        phone=phone, password="secret123", first_name="Bailleur", last_name=phone,
        role=User.ROLE_BAILLEUR,
    )


def _make_client(phone):
    return User.objects.create_user(
        phone=phone, password="secret123", first_name="Client", last_name=phone,
        role=User.ROLE_CLIENT,
    )


def _make_property(agent, title="Bien test"):
    return Property.objects.create(
        title=title, category="Studio", type="logement", transaction_type="location",
        price=100000, commune="Cocody", district="Vallon", agent=agent,
    )


class NotificationServiceTests(APITestCase):
    """Tests 1, 2 : création + liaison au bon destinataire."""

    def test_notify_creates_a_notification_for_the_right_recipient(self):
        recipient = _make_client("+2250711117001")
        notification = NotificationService.notify(
            recipient=recipient,
            notif_type=Notification.TYPE_NEW_MESSAGE,
            title="Nouveau message",
            body="Bonjour",
        )
        self.assertEqual(Notification.objects.count(), 1)
        self.assertEqual(notification.recipient, recipient)
        self.assertEqual(notification.type, Notification.TYPE_NEW_MESSAGE)

    def test_notify_is_a_noop_when_recipient_is_the_actor(self):
        """Garde-fou central (section 6) : recipient == actor -> aucune
        notification créée, quel que soit l'appelant."""
        user = _make_client("+2250711117002")
        result = NotificationService.notify(
            recipient=user,
            notif_type=Notification.TYPE_NEW_MESSAGE,
            title="Nouveau message",
            body="Bonjour",
            actor=user,
        )
        self.assertIsNone(result)
        self.assertEqual(Notification.objects.count(), 0)

    def test_notify_still_creates_when_actor_differs_from_recipient(self):
        recipient = _make_client("+2250711117003")
        actor = _make_agent("+2250711117004")
        result = NotificationService.notify(
            recipient=recipient,
            notif_type=Notification.TYPE_NEW_MESSAGE,
            title="Nouveau message",
            body="Bonjour",
            actor=actor,
        )
        self.assertIsNotNone(result)
        self.assertEqual(Notification.objects.count(), 1)

    @patch("notifications.services.NotificationService._send_push")
    def test_notify_never_raises_even_if_push_sending_fails(self, mock_send_push):
        mock_send_push.side_effect = Exception("FCM indisponible")
        recipient = _make_client("+2250711117002")
        # `on_commit` ne s'exécute pas dans une TestCase normale (transaction
        # jamais réellement validée) — captureOnCommitCallbacks(execute=True)
        # force son exécution ici pour tester réellement le chemin d'échec.
        with self.captureOnCommitCallbacks(execute=True):
            notification = NotificationService.notify(
                recipient=recipient,
                notif_type=Notification.TYPE_NEW_MESSAGE,
                title="Test",
                body="Test",
            )
        self.assertIsNotNone(notification.id)
        mock_send_push.assert_called_once()


class NotificationApiTests(APITestCase):
    """Tests 3, 4, 5, 6 : accès strictement personnel + badge + lu/tout lire."""

    def setUp(self):
        self.user_a = _make_client("+2250711117010")
        self.user_b = _make_client("+2250711117011")
        self.notification_a = Notification.objects.create(
            recipient=self.user_a, type=Notification.TYPE_NEW_RESERVATION, title="Pour A", body=""
        )
        Notification.objects.create(
            recipient=self.user_b, type=Notification.TYPE_NEW_RESERVATION, title="Pour B", body=""
        )

    def test_user_only_sees_their_own_notifications(self):
        self.client.force_authenticate(user=self.user_a)
        response = self.client.get("/api/notifications/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        titles = [n["title"] for n in response.data["results"]]
        self.assertEqual(titles, ["Pour A"])

    def test_message_notifications_are_excluded_from_bell(self):
        Notification.objects.create(
            recipient=self.user_a, type=Notification.TYPE_NEW_MESSAGE, title="Message direct", body=""
        )
        self.client.force_authenticate(user=self.user_a)
        response = self.client.get("/api/notifications/")
        titles = [n["title"] for n in response.data["results"]]
        self.assertNotIn("Message direct", titles)

    def test_unread_count(self):
        self.client.force_authenticate(user=self.user_a)
        response = self.client.get("/api/notifications/unread-count/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["unread_count"], 1)

    def test_mark_as_read(self):
        self.client.force_authenticate(user=self.user_a)
        response = self.client.post(f"/api/notifications/{self.notification_a.id}/read/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.notification_a.refresh_from_db()
        self.assertTrue(self.notification_a.is_read)

    def test_user_cannot_mark_another_users_notification_as_read(self):
        self.client.force_authenticate(user=self.user_a)
        other = Notification.objects.get(title="Pour B")
        response = self.client.post(f"/api/notifications/{other.id}/read/")
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_mark_all_as_read(self):
        Notification.objects.create(
            recipient=self.user_a, type=Notification.TYPE_NEW_REVIEW, title="Autre pour A", body=""
        )
        self.client.force_authenticate(user=self.user_a)
        response = self.client.post("/api/notifications/read-all/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(
            Notification.objects.filter(recipient=self.user_a, is_read=False).count(), 0
        )
        # N'affecte jamais les notifications d'un autre utilisateur.
        self.assertTrue(Notification.objects.filter(recipient=self.user_b, is_read=False).exists())

    def test_anonymous_cannot_access_notifications(self):
        response = self.client.get("/api/notifications/")
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)


class DeviceTokenApiTests(APITestCase):
    """Tests 7, 8, 9 + sécurité (utilisateur A → DeviceToken B refusé)."""

    def test_register_device_token(self):
        user = _make_client("+2250711117020")
        self.client.force_authenticate(user=user)
        response = self.client.post(
            "/api/devices/", {"token": "fcm-token-1", "platform": "android"}, format="json"
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        device = DeviceToken.objects.get(token="fcm-token-1")
        self.assertEqual(device.user, user)
        self.assertEqual(device.platform, "android")
        self.assertTrue(device.is_active)

    def test_register_response_never_echoes_raw_token(self):
        """Correction (audit de régression) : DeviceTokenSerializer renvoyait
        le token FCM brut dans la réponse de POST /api/devices/ (`token` était
        un champ lisible, pas seulement écrivable) — même règle que le
        masquage déjà en place côté Django Admin (DeviceTokenAdmin.
        masked_token). Le token n'a plus besoin d'être ré-émis : l'appareil
        appelant le connaît déjà (c'est lui qui vient de l'envoyer)."""
        user = _make_client("+2250711117026")
        self.client.force_authenticate(user=user)
        response = self.client.post(
            "/api/devices/", {"token": "fcm-secret-token", "platform": "android"}, format="json"
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertNotIn("token", response.data)
        # Les autres champs restent bien présents (pas une régression de
        # sérialisation complète, seul `token` doit disparaître).
        self.assertEqual(response.data["platform"], "android")
        self.assertTrue(response.data["is_active"])

    def test_user_can_register_multiple_devices(self):
        user = _make_client("+2250711117021")
        self.client.force_authenticate(user=user)
        self.client.post("/api/devices/", {"token": "android-1", "platform": "android"}, format="json")
        self.client.post("/api/devices/", {"token": "ios-1", "platform": "ios"}, format="json")
        self.assertEqual(DeviceToken.objects.filter(user=user).count(), 2)

    def test_rejects_invalid_platform(self):
        user = _make_client("+2250711117022")
        self.client.force_authenticate(user=user)
        response = self.client.post(
            "/api/devices/", {"token": "x", "platform": "windows"}, format="json"
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_deactivate_only_affects_own_token(self):
        owner = _make_client("+2250711117023")
        intruder = _make_client("+2250711117024")
        DeviceToken.objects.create(user=owner, token="owner-token", platform="android")

        self.client.force_authenticate(user=intruder)
        self.client.post("/api/devices/deactivate/", {"token": "owner-token"}, format="json")

        device = DeviceToken.objects.get(token="owner-token")
        # L'appel n'a rien désactivé : le filtre inclut `user=request.user`.
        self.assertTrue(device.is_active)

    def test_owner_can_deactivate_their_own_token(self):
        owner = _make_client("+2250711117025")
        DeviceToken.objects.create(user=owner, token="own-token", platform="ios")

        self.client.force_authenticate(user=owner)
        response = self.client.post(
            "/api/devices/deactivate/", {"token": "own-token"}, format="json"
        )

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        device = DeviceToken.objects.get(token="own-token")
        self.assertFalse(device.is_active)


class BusinessNotificationTriggerTests(APITestCase):
    """Tests 10, 11, 12 : réservation / message / avis créent bien une
    notification pour le bon destinataire."""

    def test_reservation_notifies_the_owner_but_never_the_reserving_client(self):
        """L'acteur (le client qui réserve) ne reçoit jamais de notification
        pour sa propre réservation — voir la correction métier "recipient !=
        actor". property_occupied n'est plus non plus envoyée ici : une
        réservation ne rend plus le bien occupé automatiquement (voir
        ReservationDoesNotAutoOccupyPropertyTests côté reservations/tests.py)."""
        agent = _make_agent("+2250711117030")
        client_user = _make_client("+2250711117031")
        property_obj = _make_property(agent)

        self.client.force_authenticate(user=client_user)
        response = self.client.post(
            "/api/reservations/",
            {"property_id": property_obj.id, "rent": 100000, "deposit": 0, "advance": 0},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)

        self.assertFalse(Notification.objects.filter(recipient=client_user).exists())
        self.assertTrue(
            Notification.objects.filter(
                recipient=agent, type=Notification.TYPE_NEW_RESERVATION
            ).exists()
        )
        self.assertFalse(
            Notification.objects.filter(
                recipient=agent, type=Notification.TYPE_PROPERTY_OCCUPIED
            ).exists()
        )

    def test_reservation_on_a_bailleurs_property_notifies_the_bailleur_not_an_agent(self):
        bailleur = _make_bailleur("+2250711117032")
        client_user = _make_client("+2250711117033")
        property_obj = _make_property(bailleur)

        self.client.force_authenticate(user=client_user)
        self.client.post(
            "/api/reservations/",
            {"property_id": property_obj.id, "rent": 100000, "deposit": 0, "advance": 0},
            format="json",
        )

        self.assertTrue(
            Notification.objects.filter(
                recipient=bailleur, type=Notification.TYPE_NEW_RESERVATION
            ).exists()
        )

    def test_message_creates_a_notification_for_the_receiver_only(self):
        bailleur = _make_bailleur("+2250711117034")
        agent = _make_agent("+2250711117035")
        self.client.force_authenticate(user=bailleur)
        conv_response = self.client.post("/api/conversations/", {"agent": agent.id}, format="json")
        conversation_id = conv_response.data["id"]

        self.client.post(
            "/api/messages/",
            {"conversation_id": conversation_id, "content": "Bonjour"},
            format="json",
        )

        self.assertTrue(
            Notification.objects.filter(
                recipient=agent, type=Notification.TYPE_NEW_MESSAGE
            ).exists()
        )
        self.assertFalse(
            Notification.objects.filter(
                recipient=bailleur, type=Notification.TYPE_NEW_MESSAGE
            ).exists()
        )

    def test_review_notifies_the_real_property_owner(self):
        bailleur = _make_bailleur("+2250711117036")
        client_user = _make_client("+2250711117037")
        property_obj = _make_property(bailleur, "Bien du bailleur")
        # Un avis n'est autorisé qu'après une réservation "accomplie" sur ce
        # bien précis (voir reviews/views.py::perform_create) — sans cette
        # réservation, la requête ci-dessous serait rejetée en 403 et
        # n'enverrait donc aucune notification, ce qui casserait ce test pour
        # une raison étrangère à ce qu'il vérifie réellement.
        Reservation.objects.create(
            property=property_obj, user=client_user, rent=100000, deposit=0, advance=0,
            status="accomplie",
        )

        self.client.force_authenticate(user=client_user)
        self.client.post(
            f"/api/properties/{property_obj.id}/reviews/",
            {"rating": 5, "comment": "Très bien"},
            format="json",
        )

        self.assertTrue(
            Notification.objects.filter(
                recipient=bailleur, type=Notification.TYPE_NEW_REVIEW
            ).exists()
        )

    def test_reviewing_own_property_does_not_self_notify(self):
        """Cas limite couvert par le garde-fou recipient != actor : si le
        propriétaire du bien laisse lui-même un avis, il n'est pas notifié
        de son propre avis."""
        agent = _make_agent("+2250711117042")
        property_obj = _make_property(agent, "Bien de l'agent")
        # Même contrainte que ci-dessus : une réservation "accomplie" est
        # requise avant de pouvoir laisser un avis, y compris ici où c'est le
        # propriétaire lui-même qui réserve puis avise son propre bien — seul
        # moyen de continuer à exercer réellement le garde-fou
        # recipient != actor que ce test vérifie.
        Reservation.objects.create(
            property=property_obj, user=agent, rent=100000, deposit=0, advance=0,
            status="accomplie",
        )

        self.client.force_authenticate(user=agent)
        self.client.post(
            f"/api/properties/{property_obj.id}/reviews/",
            {"rating": 5, "comment": "Auto-avis"},
            format="json",
        )

        self.assertFalse(
            Notification.objects.filter(
                recipient=agent, type=Notification.TYPE_NEW_REVIEW
            ).exists()
        )

    def test_reservation_confirmation_via_admin_status_change_notifies_the_client(self):
        agent = _make_agent("+2250711117038")
        client_user = _make_client("+2250711117039")
        property_obj = _make_property(agent)
        reservation = Reservation.objects.create(
            property=property_obj, user=client_user, rent=100000, deposit=0, advance=0,
            status="enCours",
        )
        Notification.objects.filter(recipient=client_user).delete()

        # Simule ce que fait l'admin Django en changeant le statut.
        reservation.status = "accomplie"
        reservation.save(update_fields=["status"])

        self.assertTrue(
            Notification.objects.filter(
                recipient=client_user, type=Notification.TYPE_RESERVATION_CONFIRMED
            ).exists()
        )

    def test_confirmation_signal_does_not_fire_twice_for_an_already_confirmed_reservation(self):
        agent = _make_agent("+2250711117040")
        client_user = _make_client("+2250711117041")
        property_obj = _make_property(agent)
        reservation = Reservation.objects.create(
            property=property_obj, user=client_user, rent=100000, deposit=0, advance=0,
            status="accomplie",
        )
        Notification.objects.filter(recipient=client_user).delete()

        # Une sauvegarde sans changement de statut ne doit rien notifier.
        reservation.save(update_fields=["status"])

        self.assertFalse(
            Notification.objects.filter(
                recipient=client_user, type=Notification.TYPE_RESERVATION_CONFIRMED
            ).exists()
        )


class FcmFailureDoesNotBreakBusinessLogicTests(APITestCase):
    """Test 13 : une erreur FCM ne doit jamais faire échouer une opération
    métier (ici, la création d'une réservation)."""

    @patch("notifications.services.firebase_messaging")
    @patch("notifications.services._get_firebase_app")
    def test_reservation_succeeds_even_if_fcm_send_raises(self, mock_get_app, mock_messaging):
        mock_get_app.return_value = object()
        mock_messaging.send_each_for_multicast.side_effect = Exception("Erreur réseau FCM")

        agent = _make_agent("+2250711117050")
        client_user = _make_client("+2250711117051")
        property_obj = _make_property(agent)
        DeviceToken.objects.create(user=agent, token="agent-token", platform="android")

        self.client.force_authenticate(user=client_user)
        with self.captureOnCommitCallbacks(execute=True):
            response = self.client.post(
                "/api/reservations/",
                {"property_id": property_obj.id, "rent": 100000, "deposit": 0, "advance": 0},
                format="json",
            )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        # La réservation existe bel et bien malgré l'échec FCM.
        self.assertTrue(Reservation.objects.filter(property=property_obj).exists())
        # Le mock a bien été atteint (sinon le test ne prouverait rien).
        mock_messaging.send_each_for_multicast.assert_called()


class InvalidTokenDeactivationTests(APITestCase):
    """Test 14 : un token FCM signalé invalide par Firebase est désactivé
    automatiquement, sans jamais supprimer l'historique de notifications."""

    @patch("notifications.services.firebase_messaging")
    @patch("notifications.services._get_firebase_app")
    def test_unregistered_token_is_deactivated(self, mock_get_app, mock_messaging):
        recipient = _make_client("+2250711117060")
        device = DeviceToken.objects.create(user=recipient, token="stale-token", platform="ios")

        mock_get_app.return_value = object()

        class _FakeError(Exception):
            pass

        mock_messaging.UnregisteredError = _FakeError

        class _FakeResult:
            success = False
            exception = _FakeError()

        class _FakeResponse:
            responses = [_FakeResult()]

        mock_messaging.send_each_for_multicast.return_value = _FakeResponse()

        with patch(
            "notifications.services._is_unregistered_token_error", return_value=True
        ):
            with self.captureOnCommitCallbacks(execute=True):
                NotificationService.notify(
                    recipient=recipient,
                    notif_type=Notification.TYPE_NEW_MESSAGE,
                    title="Test",
                    body="Test",
                )

        device.refresh_from_db()
        self.assertFalse(device.is_active)
        # L'historique de notifications reste intact.
        self.assertEqual(Notification.objects.filter(recipient=recipient).count(), 1)


class FcmPayloadContainsNotificationIdTests(APITestCase):
    """Correction (mission de finalisation) : le payload FCM n'incluait
    jamais notification.id — Flutter ne pouvait donc jamais marquer comme
    lue une notification ouverte depuis un VRAI push (seul le clic depuis
    l'écran Notifications in-app le pouvait). notification_id doit être
    présent et correct, et ne jamais être écrasable par `data`."""

    @patch("notifications.services.firebase_messaging")
    @patch("notifications.services._get_firebase_app")
    def test_notification_id_is_included_and_never_overridden_by_data(
        self, mock_get_app, mock_messaging
    ):
        recipient = _make_client("+2250711117070")
        DeviceToken.objects.create(user=recipient, token="a-token", platform="android")
        mock_get_app.return_value = object()

        class _FakeResult:
            success = True

        class _FakeResponse:
            responses = [_FakeResult()]

        mock_messaging.send_each_for_multicast.return_value = _FakeResponse()

        with self.captureOnCommitCallbacks(execute=True):
            notification = NotificationService.notify(
                recipient=recipient,
                notif_type=Notification.TYPE_NEW_MESSAGE,
                title="Test",
                body="Test",
                # Tentative (par erreur) de fournir une clé "notification_id"
                # dans data : ne doit jamais pouvoir écraser le vrai id.
                data={"conversation_id": "42", "notification_id": "usurpé"},
            )

        sent_message = mock_messaging.MulticastMessage.call_args.kwargs["data"]
        self.assertEqual(sent_message["notification_id"], str(notification.id))
        self.assertEqual(sent_message["conversation_id"], "42")


class DeviceTokenAdminMaskingTests(TestCase):
    """Correction : DeviceTokenAdmin affichait le token FCM complet, en
    clair et éditable, dans la fiche de détail Django Admin (aucun `fields`
    explicite ne restreignait le formulaire par défaut). masked_token()
    (voir notifications/admin.py) le remplace partout — jamais le champ réel
    `token`, qui ne doit plus jamais transiter tel quel vers le HTML rendu."""

    FULL_TOKEN = "fGz9-realistic-fcm-registration-token-abcdefghijklmnop-1234567890"

    @classmethod
    def setUpTestData(cls):
        cls.superuser = User.objects.create_superuser(
            phone="+2250700000099", password="secret123", first_name="Admin", last_name="Root",
        )
        cls.agent = _make_agent("+2250711119901")
        cls.device_token = DeviceToken.objects.create(
            user=cls.agent, token=cls.FULL_TOKEN, platform=DeviceToken.PLATFORM_ANDROID,
        )

    def test_full_token_never_appears_in_the_changelist(self):
        self.client.force_login(self.superuser)
        response = self.client.get(reverse("admin:notifications_devicetoken_changelist"))
        self.assertEqual(response.status_code, 200)
        content = response.content.decode()
        self.assertNotIn(self.FULL_TOKEN, content)
        self.assertIn("fGz9-reali", content)  # début de la version tronquée

    def test_full_token_never_appears_in_the_change_page(self):
        self.client.force_login(self.superuser)
        response = self.client.get(
            reverse("admin:notifications_devicetoken_change", args=[self.device_token.pk])
        )
        self.assertEqual(response.status_code, 200)
        content = response.content.decode()
        self.assertNotIn(self.FULL_TOKEN, content)
        self.assertIn("fGz9-reali", content)
        self.assertIn("7890", content)  # fin de la version tronquée

    def test_saving_the_change_form_does_not_alter_the_stored_token(self):
        """Le token réel n'étant plus dans `fields`, l'enregistrer depuis
        l'admin ne doit jamais l'écraser ni le vider."""
        self.client.force_login(self.superuser)
        url = reverse("admin:notifications_devicetoken_change", args=[self.device_token.pk])
        response = self.client.post(
            url,
            {
                "user": self.agent.id,
                "platform": DeviceToken.PLATFORM_IOS,
                "is_active": "on",
                "_save": "Enregistrer",
            },
        )
        self.assertEqual(response.status_code, 302)  # redirection = sauvegarde réussie

        self.device_token.refresh_from_db()
        self.assertEqual(self.device_token.token, self.FULL_TOKEN)
        self.assertEqual(self.device_token.platform, DeviceToken.PLATFORM_IOS)  # l'édition marche bien
