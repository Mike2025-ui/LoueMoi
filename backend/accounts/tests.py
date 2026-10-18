from datetime import timedelta
from unittest.mock import patch

from django.contrib.auth import get_user_model
from django.contrib.auth.hashers import make_password
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APITestCase

from .models import PasswordResetOTP

User = get_user_model()


class RoleRegistrationTests(APITestCase):
    """Tests 1, 2, 12 (voir cahier des charges section 30)."""

    def test_user_created_by_default_as_client(self):
        response = self.client.post(
            "/api/auth/register/",
            {
                "first_name": "Awa",
                "last_name": "Kone",
                "phone": "+2250700000010",
                "password": "secret123",
                "password_confirm": "secret123",
            },
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data["role"], "client")
        user = User.objects.get(phone="+2250700000010")
        self.assertEqual(user.role, User.ROLE_CLIENT)
        self.assertFalse(hasattr(user, "agent_profile"))

    def test_agent_registration_creates_unverified_agent_profile(self):
        response = self.client.post(
            "/api/auth/register/",
            {
                "first_name": "Kofi",
                "last_name": "Assamoi",
                "phone": "+2250700000011",
                "whatsapp": "+2250700000011",
                "password": "secret123",
                "password_confirm": "secret123",
                "role": "agent",
            },
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data["role"], "agent")
        user = User.objects.get(phone="+2250700000011")
        self.assertTrue(hasattr(user, "agent_profile"))
        # Un agent ne peut jamais s'auto-vérifier à l'inscription.
        self.assertFalse(user.agent_profile.is_verified)
        # Compte en attente d'activation administrateur
        self.assertFalse(user.is_approved)

    def test_bailleur_registration(self):
        response = self.client.post(
            "/api/auth/register/",
            {
                "first_name": "Adjoua",
                "last_name": "N'Guessan",
                "phone": "+2250700000016",
                "whatsapp": "+2250700000016",
                "password": "secret123",
                "password_confirm": "secret123",
                "role": "bailleur",
            },
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data["role"], "bailleur")
        user = User.objects.get(phone="+2250700000016")
        self.assertEqual(user.role, User.ROLE_BAILLEUR)
        # Un bailleur n'a pas de profil professionnel structuré (pas
        # d'AgentProfile) — rôle strictement indépendant de l'agent.
        self.assertFalse(hasattr(user, "agent_profile"))
        self.assertFalse(user.is_approved)

    def test_agent_or_bailleur_registration_requires_whatsapp(self):
        response = self.client.post(
            "/api/auth/register/",
            {
                "first_name": "No",
                "last_name": "WhatsApp",
                "phone": "+2250700000095",
                "password": "secret123",
                "password_confirm": "secret123",
                "role": "agent",
            },
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn("whatsapp", response.data)

    def test_public_registration_cannot_create_admin(self):
        response = self.client.post(
            "/api/auth/register/",
            {
                "first_name": "Hack",
                "last_name": "Er",
                "phone": "+2250700000012",
                "password": "secret123",
                "password_confirm": "secret123",
                "role": "admin",
            },
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertFalse(User.objects.filter(phone="+2250700000012").exists())


class AdminRoleManagementTests(APITestCase):
    """Règle de sécurité stricte : le rôle des clients, agents et bailleurs ainsi que les numéros
    de téléphone ne doivent JAMAIS être modifiables."""

    def test_role_and_phone_are_strictly_immutable(self):
        target = User.objects.create_user(
            phone="+2250700000014", password="secret123", first_name="A", last_name="B", role=User.ROLE_CLIENT,
        )
        self.assertEqual(target.role, User.ROLE_CLIENT)
        self.assertEqual(target.phone, "+2250700000014")

        # Tentative de modification directe de rôle et de téléphone
        target.role = User.ROLE_AGENT
        target.phone = "+2250799999999"
        target.save()
        target.refresh_from_db()

        # Le rôle et le téléphone restent strictement inchangés
        self.assertEqual(target.role, User.ROLE_CLIENT)
        self.assertEqual(target.phone, "+2250700000014")

    def test_client_cannot_have_certificate_badge(self):
        target = User.objects.create_user(
            phone="+2250700000018", password="secret123", first_name="A", last_name="B", role=User.ROLE_CLIENT,
        )
        target.is_verified = True
        target.save()
        target.refresh_from_db()
        self.assertFalse(target.is_verified)

    def test_role_is_not_editable_via_public_me_endpoint(self):
        user = User.objects.create_user(
            phone="+2250700000015", password="secret123", first_name="A", last_name="B"
        )
        self.client.force_authenticate(user=user)
        response = self.client.patch("/api/users/me/", {"role": "agent", "phone": "+2250799999999"}, format="json")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        user.refresh_from_db()
        # `role` et `phone` sont protégés en lecture seule : la tentative est ignorée.
        self.assertEqual(user.role, User.ROLE_CLIENT)
        self.assertEqual(user.phone, "+2250700000015")


class LoginAndMeRoleTests(APITestCase):
    """Tests 5, 6, 7, 8 (mission finalisation, section VALIDATION FINALE) :
    login par rôle + /api/users/me/ retourne le bon rôle dans chaque cas."""

    def _register(self, phone, role):
        response = self.client.post(
            "/api/auth/register/",
            {
                "first_name": "Test",
                "last_name": role,
                "phone": phone,
                "whatsapp": phone,
                "password": "secret123",
                "password_confirm": "secret123",
                "role": role,
            },
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)

    def _assert_login_and_me_role(self, phone, role):
        self._register(phone, role)
        login_response = self.client.post(
            "/api/auth/login/", {"phone": phone, "password": "secret123"}, format="json"
        )
        self.assertEqual(login_response.status_code, status.HTTP_200_OK)
        self.assertEqual(login_response.data["role"], role)

        token = login_response.data["token"]
        me_response = self.client.get(
            "/api/users/me/", HTTP_AUTHORIZATION=f"Bearer {token}"
        )
        self.assertEqual(me_response.status_code, status.HTTP_200_OK)
        self.assertEqual(me_response.data["role"], role)

    def test_login_and_me_for_client(self):
        self._assert_login_and_me_role("+2250700000020", "client")

    def test_login_and_me_for_bailleur(self):
        self._assert_login_and_me_role("+2250700000021", "bailleur")

    def test_login_and_me_for_agent(self):
        self._assert_login_and_me_role("+2250700000022", "agent")


class PasswordResetTests(APITestCase):
    """"Mot de passe oublié" : Numéro → OTP SMS → Vérification + nouveau mot
    de passe → Connexion. Architecture complète et réelle (code aléatoire,
    haché, expire, tentatives limitées) ; seul l'envoi SMS est un bouchon de
    développement tant qu'aucun fournisseur n'est configuré (accounts/sms.py).
    Le code n'étant jamais renvoyé par l'API (par design anti-fuite), les
    tests fixent random.choices pour connaître le code généré."""

    def setUp(self):
        self.user = User.objects.create_user(
            phone="+2250700000040", password="ancien-mdp", first_name="A", last_name="B",
        )

    def _request_with_fixed_code(self, phone, code="123456"):
        # Patcher accounts.models.secrets.choice directement patcherait le
        # module secrets PARTAGÉ par tout le process — y compris
        # make_password() de Django, qui l'utilise pour générer le sel du
        # hash, cassant le hachage lui-même. On patche donc uniquement la
        # classmethod generate_for() pour produire un OTP réel (vraiment
        # haché) mais avec un code connu, sans toucher à `secrets` global.
        def fake_generate_for(user):
            otp = PasswordResetOTP.objects.create(
                user=user,
                code_hash=make_password(code),
                expires_at=timezone.now() + timedelta(minutes=PasswordResetOTP.VALIDITY_MINUTES),
            )
            return otp, code

        with patch.object(PasswordResetOTP, "generate_for", side_effect=fake_generate_for):
            return self.client.post(
                "/api/auth/password-reset/request/", {"phone": phone}, format="json"
            )

    def test_request_generates_an_otp_and_never_returns_the_code(self):
        response = self._request_with_fixed_code(self.user.phone)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertNotIn("123456", str(response.data))
        self.assertEqual(PasswordResetOTP.objects.filter(user=self.user).count(), 1)

    def test_request_for_unknown_phone_returns_the_same_generic_response(self):
        known = self._request_with_fixed_code(self.user.phone)
        unknown = self.client.post(
            "/api/auth/password-reset/request/", {"phone": "+2250799999999"}, format="json"
        )
        self.assertEqual(known.status_code, unknown.status_code)
        self.assertEqual(known.data, unknown.data)
        # Aucun OTP créé pour un numéro qui n'existe pas.
        self.assertEqual(PasswordResetOTP.objects.exclude(user=self.user).count(), 0)

    def test_request_is_rate_limited_by_cooldown(self):
        self._request_with_fixed_code(self.user.phone, code="111111")
        self._request_with_fixed_code(self.user.phone, code="222222")
        # Un seul OTP créé : la 2e demande, dans la fenêtre de cooldown, n'en
        # génère pas un nouveau.
        self.assertEqual(PasswordResetOTP.objects.filter(user=self.user).count(), 1)

    def test_confirm_with_correct_code_resets_the_password(self):
        self._request_with_fixed_code(self.user.phone, code="654321")
        response = self.client.post(
            "/api/auth/password-reset/confirm/",
            {"phone": self.user.phone, "code": "654321", "new_password": "nouveau-mdp-123"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)

        self.user.refresh_from_db()
        self.assertTrue(self.user.check_password("nouveau-mdp-123"))
        self.assertFalse(self.user.check_password("ancien-mdp"))

        # Peut ensuite se connecter avec le nouveau mot de passe.
        login = self.client.post(
            "/api/auth/login/",
            {"phone": self.user.phone, "password": "nouveau-mdp-123"},
            format="json",
        )
        self.assertEqual(login.status_code, status.HTTP_200_OK)

    def test_confirm_with_wrong_code_is_rejected_password_unchanged(self):
        self._request_with_fixed_code(self.user.phone, code="654321")
        response = self.client.post(
            "/api/auth/password-reset/confirm/",
            {"phone": self.user.phone, "code": "000000", "new_password": "nouveau-mdp-123"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.user.refresh_from_db()
        self.assertTrue(self.user.check_password("ancien-mdp"))

    def test_confirm_rejects_a_used_code(self):
        self._request_with_fixed_code(self.user.phone, code="654321")
        self.client.post(
            "/api/auth/password-reset/confirm/",
            {"phone": self.user.phone, "code": "654321", "new_password": "nouveau-mdp-123"},
            format="json",
        )
        second_attempt = self.client.post(
            "/api/auth/password-reset/confirm/",
            {"phone": self.user.phone, "code": "654321", "new_password": "autre-mdp-456"},
            format="json",
        )
        self.assertEqual(second_attempt.status_code, status.HTTP_400_BAD_REQUEST)

    def test_confirm_rejects_an_expired_code(self):
        self._request_with_fixed_code(self.user.phone, code="654321")
        otp = PasswordResetOTP.objects.get(user=self.user)
        otp.expires_at = timezone.now() - timedelta(minutes=1)
        otp.save(update_fields=["expires_at"])

        response = self.client.post(
            "/api/auth/password-reset/confirm/",
            {"phone": self.user.phone, "code": "654321", "new_password": "nouveau-mdp-123"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_confirm_locks_out_after_max_attempts(self):
        self._request_with_fixed_code(self.user.phone, code="654321")
        for _ in range(PasswordResetOTP.MAX_ATTEMPTS):
            self.client.post(
                "/api/auth/password-reset/confirm/",
                {"phone": self.user.phone, "code": "000000", "new_password": "x123456"},
                format="json",
            )
        # Même le bon code échoue désormais : plus de tentatives disponibles.
        response = self.client.post(
            "/api/auth/password-reset/confirm/",
            {"phone": self.user.phone, "code": "654321", "new_password": "nouveau-mdp-123"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.user.refresh_from_db()
        self.assertTrue(self.user.check_password("ancien-mdp"))

    def test_confirm_rejects_too_short_password(self):
        self._request_with_fixed_code(self.user.phone, code="654321")
        response = self.client.post(
            "/api/auth/password-reset/confirm/",
            {"phone": self.user.phone, "code": "654321", "new_password": "abc"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_deactivated_account_cannot_still_reset_and_login(self):
        """Réinitialiser le mot de passe ne réactive pas un compte
        désactivé — is_active reste sous le contrôle exclusif de
        DeactivateAccountView, jamais un effet de bord de cet endpoint."""
        self.user.is_active = False
        self.user.save(update_fields=["is_active"])

        self._request_with_fixed_code(self.user.phone, code="654321")
        confirm = self.client.post(
            "/api/auth/password-reset/confirm/",
            {"phone": self.user.phone, "code": "654321", "new_password": "nouveau-mdp-123"},
            format="json",
        )
        self.assertEqual(confirm.status_code, status.HTTP_200_OK)

        login = self.client.post(
            "/api/auth/login/",
            {"phone": self.user.phone, "password": "nouveau-mdp-123"},
            format="json",
        )
        self.assertEqual(login.status_code, status.HTTP_403_FORBIDDEN)


class DeactivateAccountTests(APITestCase):
    """Décision métier retenue : désactivation (is_active=False), jamais de
    suppression physique. Vérifie le cycle complet : mot de passe requis,
    connexion impossible après désactivation, données conservées."""

    def setUp(self):
        self.user = User.objects.create_user(
            phone="+2250700000030", password="secret123", first_name="A", last_name="B",
        )

    def test_wrong_password_is_rejected_account_stays_active(self):
        self.client.force_authenticate(user=self.user)
        response = self.client.post(
            "/api/users/me/deactivate/", {"password": "wrong"}, format="json"
        )
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)
        self.user.refresh_from_db()
        self.assertTrue(self.user.is_active)

    def test_missing_password_is_rejected(self):
        self.client.force_authenticate(user=self.user)
        response = self.client.post("/api/users/me/deactivate/", {}, format="json")
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_correct_password_deactivates_the_account(self):
        self.client.force_authenticate(user=self.user)
        response = self.client.post(
            "/api/users/me/deactivate/", {"password": "secret123"}, format="json"
        )
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)
        self.user.refresh_from_db()
        self.assertFalse(self.user.is_active)

    def test_deactivated_user_cannot_log_in_again(self):
        self.user.is_active = False
        self.user.save(update_fields=["is_active"])
        response = self.client.post(
            "/api/auth/login/",
            {"phone": self.user.phone, "password": "secret123"},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_deactivated_user_loses_access_to_authenticated_endpoints_immediately(self):
        """CHECK_USER_IS_ACTIVE (simplejwt) revérifie is_active en base à
        chaque requête, jamais depuis le token — un token émis AVANT la
        désactivation devient donc inutilisable dès la requête suivante,
        sans avoir besoin d'être révoqué explicitement.

        force_authenticate() ne convient pas ici : il injecte request.user
        directement et court-circuite entièrement JWTAuthentication (donc
        CHECK_USER_IS_ACTIVE) — un vrai token, obtenu par login, est
        nécessaire pour exercer ce chemin réellement."""
        login_response = self.client.post(
            "/api/auth/login/",
            {"phone": self.user.phone, "password": "secret123"},
            format="json",
        )
        token = login_response.data["token"]

        self.user.is_active = False
        self.user.save(update_fields=["is_active"])

        response = self.client.get("/api/users/me/", HTTP_AUTHORIZATION=f"Bearer {token}")
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_deactivation_deletes_no_data(self):
        from properties.models import Property
        from reservations.models import Reservation

        agent = User.objects.create_user(
            phone="+2250700000031", password="secret123", first_name="Ag", last_name="B",
            role=User.ROLE_AGENT,
        )
        property_obj = Property.objects.create(
            title="Bien", category="Studio", type="logement", transaction_type="location",
            price=100000, commune="X", district="Y", agent=agent,
        )
        reservation = Reservation.objects.create(
            property=property_obj, user=self.user, rent=100000, deposit=0, advance=0,
        )

        self.client.force_authenticate(user=self.user)
        self.client.post("/api/users/me/deactivate/", {"password": "secret123"}, format="json")

        self.assertTrue(Property.objects.filter(pk=property_obj.pk).exists())
        self.assertTrue(Reservation.objects.filter(pk=reservation.pk).exists())
        self.assertTrue(User.objects.filter(pk=self.user.pk).exists())


class ActivationRequestTests(APITestCase):
    def setUp(self):
        self.agent = User.objects.create_user(
            phone="+2250700000050",
            password="secret123",
            first_name="Agent",
            last_name="Test",
            role=User.ROLE_AGENT,
            whatsapp="+2250700000050",
            is_approved=False,
        )

    def test_agent_can_request_activation(self):
        self.client.force_authenticate(user=self.agent)
        response = self.client.post("/api/auth/request-activation/", format="json")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.agent.refresh_from_db()
        self.assertTrue(self.agent.activation_requested)
        self.assertIsNotNone(self.agent.activation_requested_at)
        self.assertFalse(self.agent.is_approved)

    def test_client_cannot_request_activation(self):
        client = User.objects.create_user(
            phone="+2250700000051",
            password="secret123",
            first_name="Client",
            last_name="Test",
            role=User.ROLE_CLIENT,
        )
        self.client.force_authenticate(user=client)
        response = self.client.post("/api/auth/request-activation/", format="json")
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)


class IkoddiSmsProviderTests(APITestCase):
    def test_normalize_phone_number(self):
        from accounts.sms import normalize_phone_number

        self.assertEqual(normalize_phone_number("0701020304"), "+2250701020304")
        self.assertEqual(normalize_phone_number("+225 07 01 02 03 04"), "+2250701020304")
        self.assertEqual(normalize_phone_number("002250701020304"), "+2250701020304")
        self.assertEqual(normalize_phone_number("2250701020304"), "+2250701020304")
        self.assertEqual(normalize_phone_number("+33612345678"), "+33612345678")
        self.assertEqual(normalize_phone_number(""), "")

    def test_get_sms_provider_default(self):
        import os
        from accounts.sms import LoggingSmsProvider, get_sms_provider
        from django.test import override_settings

        with override_settings(IKODDI_API_KEY=""):
            # Ensure env vars are also empty for this test
            orig_ikoddi = os.environ.pop("IKODDI_API_KEY", None)
            orig_ikkodi = os.environ.pop("IKKODI_API_KEY", None)
            try:
                provider = get_sms_provider()
                self.assertIsInstance(provider, LoggingSmsProvider)
            finally:
                if orig_ikoddi:
                    os.environ["IKODDI_API_KEY"] = orig_ikoddi
                if orig_ikkodi:
                    os.environ["IKKODI_API_KEY"] = orig_ikkodi

    def test_get_sms_provider_with_api_key(self):
        from accounts.sms import IkoddiSmsProvider, get_sms_provider
        from django.test import override_settings

        with override_settings(IKODDI_API_KEY="test-key-123"):
            provider = get_sms_provider()
            self.assertIsInstance(provider, IkoddiSmsProvider)
            self.assertEqual(provider.api_key, "test-key-123")
            self.assertEqual(provider.sender_id, "LoueMoi")

    def test_ikoddi_sms_provider_send_success(self):
        import io
        import json
        from unittest.mock import patch
        from accounts.sms import IkoddiSmsProvider

        provider = IkoddiSmsProvider(api_key="secret-api-key", sender_id="LoueMoi")

        class MockResponse:
            status = 200
            def read(self):
                return b'{"status": "success", "message_id": "msg-123"}'
            def __enter__(self):
                return self
            def __exit__(self, *args):
                pass

        with patch("urllib.request.urlopen", return_value=MockResponse()) as mock_urlopen:
            success = provider.send("0701020304", "Votre code LoueMoi : 123456")
            self.assertTrue(success)
            self.assertTrue(mock_urlopen.called)
            req = mock_urlopen.call_args[0][0]
            self.assertEqual(req.headers.get("Authorization"), "Bearer secret-api-key")
            sent_data = json.loads(req.data.decode("utf-8"))
            self.assertEqual(sent_data["to"], "+2250701020304")
            self.assertEqual(sent_data["sender"], "LoueMoi")
            self.assertEqual(sent_data["message"], "Votre code LoueMoi : 123456")

    def test_ikoddi_sms_provider_handles_http_error(self):
        import urllib.error
        from unittest.mock import patch
        from accounts.sms import IkoddiSmsProvider

        provider = IkoddiSmsProvider(api_key="invalid-key")
        http_err = urllib.error.HTTPError(
            url="https://api.ikoddi.com/v1/sms/send",
            code=401,
            msg="Unauthorized",
            hdrs={},
            fp=None,
        )

        with patch("urllib.request.urlopen", side_effect=http_err):
            success = provider.send("0701020304", "Test message")
            self.assertFalse(success)

    def test_ikoddi_sms_provider_handles_network_error(self):
        import urllib.error
        from unittest.mock import patch
        from accounts.sms import IkoddiSmsProvider

        provider = IkoddiSmsProvider(api_key="any-key")
        url_err = urllib.error.URLError(reason="Connection refused")

        with patch("urllib.request.urlopen", side_effect=url_err):
            success = provider.send("0701020304", "Test message")
            self.assertFalse(success)

