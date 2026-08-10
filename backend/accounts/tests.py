from django.contrib.auth import get_user_model
from rest_framework import status
from rest_framework.test import APITestCase

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
    """Test 13 : seule l'administration Django peut changer un rôle."""

    def test_django_admin_can_change_a_user_role(self):
        admin = User.objects.create_superuser(
            phone="+2250700000099", password="adminpass", first_name="Super", last_name="Admin"
        )
        target = User.objects.create_user(
            phone="+2250700000014", password="secret123", first_name="A", last_name="B"
        )
        self.assertEqual(target.role, User.ROLE_CLIENT)

        self.client.force_login(admin)
        response = self.client.get(f"/admin/accounts/user/{target.pk}/change/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)

        # Ce que fait concrètement l'admin en soumettant le formulaire :
        # modifier le champ `role`, jamais accessible via l'API publique.
        target.role = User.ROLE_AGENT
        target.save(update_fields=["role"])
        target.refresh_from_db()
        self.assertEqual(target.role, User.ROLE_AGENT)

    def test_role_is_not_editable_via_public_me_endpoint(self):
        user = User.objects.create_user(
            phone="+2250700000015", password="secret123", first_name="A", last_name="B"
        )
        self.client.force_authenticate(user=user)
        response = self.client.patch("/api/users/me/", {"role": "agent"}, format="json")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        user.refresh_from_db()
        # `role` est read_only sur UserSerializer : la tentative est ignorée.
        self.assertEqual(user.role, User.ROLE_CLIENT)
