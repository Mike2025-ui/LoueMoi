from django.contrib.auth import get_user_model
from django.core.files.uploadedfile import SimpleUploadedFile
from rest_framework import status
from rest_framework.test import APITestCase

from .models import Conversation, Message

User = get_user_model()

# JPEG 1x1 minimal — suffisant pour exercer l'upload multipart réel (jamais
# un mock de fichier), sans dépendre de Pillow pour la validation.
_TINY_JPEG = bytes.fromhex(
    "ffd8ffe000104a4649460001010100480048000000ffdb004300ffffffffd9"
)


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


def _subscribe(user):
    from datetime import timedelta
    from django.utils import timezone
    from payments.models import Subscription
    plan = Subscription.PLAN_PRO if user.role in (User.ROLE_AGENT, User.ROLE_BAILLEUR) else Subscription.PLAN_CLIENT
    sub, _ = Subscription.objects.get_or_create(
        user=user,
        defaults={
            "plan": plan,
            "amount": 3000 if plan == Subscription.PLAN_PRO else 1000,
            "reference": f"SUB-TEST-{user.phone}",
            "status": Subscription.STATUS_ACTIVE,
            "started_at": timezone.now(),
            "expires_at": timezone.now() + timedelta(days=30),
        },
    )
    user.is_verified = True
    user.save(update_fields=["is_verified"])
    return sub


class ConversationCreationTests(APITestCase):
    """Test 24, 25 : un bailleur (ou un client) peut contacter un agent ;
    l'agent peut répondre — un seul système de messagerie, réutilisé tel
    quel pour les deux rôles."""

    def test_bailleur_can_contact_agent(self):
        bailleur = _make_bailleur("+2250711116001")
        agent = _make_agent("+2250711116002")
        self.client.force_authenticate(user=bailleur)

        response = self.client.post("/api/conversations/", {"agent": agent.id}, format="json")

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data["client"], bailleur.id)
        self.assertEqual(response.data["agent"], agent.id)

    def test_agent_can_contact_a_bailleur(self):
        """Correction : le slot "agent" d'une Conversation accepte aussi un
        bailleur (voir ConversationSerializer.validate_agent) — sans ça,
        "Contacter l'agent" échouait pour toute annonce publiée par un
        bailleur (Property.agent peut être un bailleur), et "Rechercher un
        propriétaire" (contacter un bailleur trouvé via /api/bailleurs/)
        aurait échoué de la même façon."""
        agent = _make_agent("+2250711116007")
        bailleur = _make_bailleur("+2250711116008")
        self.client.force_authenticate(user=agent)

        response = self.client.post("/api/conversations/", {"agent": bailleur.id}, format="json")

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data["client"], agent.id)
        self.assertEqual(response.data["agent"], bailleur.id)

    def test_agent_can_respond_in_the_conversation(self):
        bailleur = _make_bailleur("+2250711116003")
        agent = _make_agent("+2250711116004")
        _subscribe(agent)
        conversation = Conversation.objects.create(client=bailleur, agent=agent)

        self.client.force_authenticate(user=agent)
        response = self.client.post(
            "/api/messages/",
            {"conversation_id": conversation.id, "content": "Bonjour, je peux vous aider."},
            format="json",
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data["sender_id"], agent.id)
        self.assertEqual(response.data["receiver_id"], bailleur.id)

    def test_conversation_agent_field_must_be_a_real_agent(self):
        bailleur = _make_bailleur("+2250711116005")
        not_an_agent = _make_client("+2250711116006")
        self.client.force_authenticate(user=bailleur)

        response = self.client.post(
            "/api/conversations/", {"agent": not_an_agent.id}, format="json"
        )

    def test_cannot_create_duplicate_conversation_between_same_users(self):
        client = _make_client("+2250711116007")
        agent = _make_agent("+2250711116008")
        self.client.force_authenticate(user=client)

        # 1er appel : création sans propriété
        r1 = self.client.post("/api/conversations/", {"agent": agent.id}, format="json")
        self.assertEqual(r1.status_code, status.HTTP_201_CREATED)
        conv_id = r1.data["id"]

        # 2e appel : même agent, doit renvoyer la même conversation sans doublon
        r2 = self.client.post("/api/conversations/", {"agent": agent.id}, format="json")
        self.assertEqual(r2.status_code, status.HTTP_201_CREATED)
        self.assertEqual(r2.data["id"], conv_id)
        self.assertEqual(Conversation.objects.filter(client=client, agent=agent).count(), 1)


class MessageNotificationTests(APITestCase):
    """L'expéditeur d'un message ne doit jamais recevoir de notification pour
    son propre envoi (NotificationService.notify(actor=...), voir
    messaging/views.py::perform_create) — seul le destinataire réel est
    notifié."""

    def test_sender_receives_no_notification_recipient_does(self):
        from notifications.models import Notification

        bailleur = _make_bailleur("+2250711116050")
        agent = _make_agent("+2250711116051")
        _subscribe(bailleur)
        conversation = Conversation.objects.create(client=bailleur, agent=agent)

        self.client.force_authenticate(user=bailleur)
        with self.captureOnCommitCallbacks(execute=True):
            response = self.client.post(
                "/api/messages/",
                {"conversation_id": conversation.id, "content": "Bonjour"},
                format="json",
            )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)

        self.assertFalse(
            Notification.objects.filter(
                recipient=bailleur, type=Notification.TYPE_NEW_MESSAGE
            ).exists()
        )
        self.assertTrue(
            Notification.objects.filter(
                recipient=agent, type=Notification.TYPE_NEW_MESSAGE
            ).exists()
        )


class ConversationAccessTests(APITestCase):
    """Test 26, 27 : seuls les participants peuvent lire une conversation."""

    def setUp(self):
        self.bailleur = _make_bailleur("+2250711116010")
        self.agent = _make_agent("+2250711116011")
        _subscribe(self.agent)
        self.outsider = _make_client("+2250711116012")
        self.conversation = Conversation.objects.create(client=self.bailleur, agent=self.agent)
        Message.objects.create(
            conversation=self.conversation, sender=self.bailleur, receiver=self.agent,
            content="Bonjour",
        )

    def test_participant_can_read_conversation_messages(self):
        self.client.force_authenticate(user=self.agent)
        response = self.client.get(f"/api/messages/?conversation={self.conversation.id}")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["count"], 1)

    def test_non_participant_cannot_read_conversation_messages(self):
        self.client.force_authenticate(user=self.outsider)
        response = self.client.get(f"/api/messages/?conversation={self.conversation.id}")
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)


class ConversationMarkReadTests(APITestCase):
    """POST /api/conversations/{id}/mark-read/ — sans ça, unread_count (et
    donc le badge de l'onglet Messages côté Flutter) ne redescend jamais."""

    def setUp(self):
        self.bailleur = _make_bailleur("+2250711116040")
        self.agent = _make_agent("+2250711116041")
        self.conversation = Conversation.objects.create(client=self.bailleur, agent=self.agent)
        Message.objects.create(
            conversation=self.conversation, sender=self.bailleur, receiver=self.agent,
            content="Bonjour",
        )
        Message.objects.create(
            conversation=self.conversation, sender=self.bailleur, receiver=self.agent,
            content="Toujours dispo ?",
        )

    def test_mark_read_clears_unread_count_for_recipient(self):
        self.client.force_authenticate(user=self.agent)
        list_response = self.client.get("/api/conversations/")
        self.assertEqual(list_response.data["results"][0]["unread_count"], 2)

        mark_response = self.client.post(f"/api/conversations/{self.conversation.id}/mark-read/")
        self.assertEqual(mark_response.status_code, status.HTTP_200_OK)

        list_response = self.client.get("/api/conversations/")
        self.assertEqual(list_response.data["results"][0]["unread_count"], 0)

    def test_mark_read_does_not_affect_messages_sent_by_the_caller(self):
        # Le bailleur (expéditeur) n'a rien à "lire" dans ses propres
        # messages : mark-read appelé par le mauvais participant ne doit pas
        # faussement marquer comme lus des messages que l'agent n'a pas
        # encore ouverts.
        self.client.force_authenticate(user=self.bailleur)
        self.client.post(f"/api/conversations/{self.conversation.id}/mark-read/")

        self.client.force_authenticate(user=self.agent)
        list_response = self.client.get("/api/conversations/")
        self.assertEqual(list_response.data["results"][0]["unread_count"], 2)

    def test_non_participant_cannot_mark_conversation_read(self):
        outsider = _make_client("+2250711116042")
        self.client.force_authenticate(user=outsider)
        response = self.client.post(f"/api/conversations/{self.conversation.id}/mark-read/")
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)


class MessageContentTypeTests(APITestCase):
    """Tests 28 à 31 : texte, image, vidéo, audio — un seul modèle Message,
    jamais un système parallèle par type."""

    def setUp(self):
        self.bailleur = _make_bailleur("+2250711116020")
        self.agent = _make_agent("+2250711116021")
        self.conversation = Conversation.objects.create(client=self.bailleur, agent=self.agent)
        self.client.force_authenticate(user=self.bailleur)

    def test_send_text_message(self):
        response = self.client.post(
            "/api/messages/",
            {"conversation_id": self.conversation.id, "content": "Bonjour, une villa à louer."},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data["attachment_type"], "text")
        self.assertIsNone(response.data["attachment_url"])

    def test_send_image_message(self):
        photo = SimpleUploadedFile("photo.jpg", _TINY_JPEG, content_type="image/jpeg")
        response = self.client.post(
            "/api/messages/",
            {
                "conversation_id": self.conversation.id,
                "content": "",
                "attachment_type": "image",
                "attachment": photo,
            },
            format="multipart",
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data["attachment_type"], "image")
        self.assertIsNotNone(response.data["attachment_url"])
        # Jamais l'URL MEDIA_URL brute : toujours l'endpoint protégé.
        self.assertIn(f"/api/messages/{response.data['id']}/attachment/",
                       response.data["attachment_url"])

    def test_send_video_message(self):
        video = SimpleUploadedFile("clip.mp4", b"\x00\x00\x00\x18ftypmp42", content_type="video/mp4")
        response = self.client.post(
            "/api/messages/",
            {
                "conversation_id": self.conversation.id,
                "content": "",
                "attachment_type": "video",
                "duration": 12,
                "attachment": video,
            },
            format="multipart",
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data["attachment_type"], "video")
        self.assertEqual(response.data["duration"], 12)

    def test_send_audio_message(self):
        audio = SimpleUploadedFile("voice.m4a", b"\x00\x00\x00\x18ftypM4A ", content_type="audio/m4a")
        response = self.client.post(
            "/api/messages/",
            {
                "conversation_id": self.conversation.id,
                "content": "",
                "attachment_type": "audio",
                "duration": 8,
                "attachment": audio,
            },
            format="multipart",
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data["attachment_type"], "audio")
        self.assertEqual(response.data["duration"], 8)

    def test_empty_message_rejected(self):
        response = self.client.post(
            "/api/messages/",
            {"conversation_id": self.conversation.id, "content": ""},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)


class MessageAttachmentSecurityTests(APITestCase):
    """Sécurité pièce jointe : seuls les participants peuvent télécharger,
    jamais via une URL MEDIA_URL publique devinable."""

    def setUp(self):
        self.bailleur = _make_bailleur("+2250711116030")
        self.agent = _make_agent("+2250711116031")
        self.outsider = _make_client("+2250711116032")
        self.conversation = Conversation.objects.create(client=self.bailleur, agent=self.agent)
        self.client.force_authenticate(user=self.bailleur)
        photo = SimpleUploadedFile("photo.jpg", _TINY_JPEG, content_type="image/jpeg")
        create_response = self.client.post(
            "/api/messages/",
            {
                "conversation_id": self.conversation.id,
                "content": "",
                "attachment_type": "image",
                "attachment": photo,
            },
            format="multipart",
        )
        self.message_id = create_response.data["id"]

    def test_participant_can_download_attachment(self):
        self.client.force_authenticate(user=self.agent)
        response = self.client.get(f"/api/messages/{self.message_id}/attachment/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)

    def test_non_participant_cannot_download_attachment(self):
        self.client.force_authenticate(user=self.outsider)
        response = self.client.get(f"/api/messages/{self.message_id}/attachment/")
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_anonymous_cannot_download_attachment(self):
        self.client.force_authenticate(user=None)
        response = self.client.get(f"/api/messages/{self.message_id}/attachment/")
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)
