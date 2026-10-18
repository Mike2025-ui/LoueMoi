from django.contrib.auth import get_user_model
from rest_framework import status
from rest_framework.test import APITestCase

from .models import AgentProfile

User = get_user_model()


def _make_agent(phone, first_name="Agent", agency_name="", description=""):
    user = User.objects.create_user(
        phone=phone, password="secret123", first_name=first_name, last_name=phone,
        role=User.ROLE_AGENT,
    )
    AgentProfile.objects.create(user=user, agency_name=agency_name, description=description)
    return user


def _make_client(phone):
    return User.objects.create_user(
        phone=phone, password="secret123", first_name="Client", last_name=phone,
        role=User.ROLE_CLIENT,
    )


import uuid
from payments.models import Subscription


def _subscribe(user):
    sub = Subscription.objects.create(
        user=user,
        plan=Subscription.PLAN_PRO if user.role in (User.ROLE_AGENT, User.ROLE_BAILLEUR) else Subscription.PLAN_CLIENT,
        amount=3000 if user.role in (User.ROLE_AGENT, User.ROLE_BAILLEUR) else 1000,
        reference=f"SUB-{uuid.uuid4().hex[:12]}",
        status=Subscription.STATUS_PENDING,
    )
    sub.activate_for_30_days()
    return sub


class AgentSearchTests(APITestCase):
    """GET /api/agents/ — réservé aux utilisateurs abonnés."""

    def setUp(self):
        self.agent_kouassi = _make_agent(
            "+2250711115001", first_name="Kouassi", agency_name="ABC Immo"
        )
        self.agent_kouakou = _make_agent(
            "+2250711115002", first_name="Kouakou", agency_name="Kouakou Immobilier"
        )
        self.client_user = _make_client("+2250711115003")
        self.client_unsubscribed = _make_client("+2250711115004")
        _subscribe(self.client_user)

    def test_unauthenticated_or_unsubscribed_cannot_search(self):
        # 1. Non connecté -> 401
        response = self.client.get("/api/agents/")
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

        # 2. Connecté mais non abonné -> 403
        self.client.force_authenticate(user=self.client_unsubscribed)
        response = self.client.get("/api/agents/")
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_subscribed_user_can_list_agents(self):
        self.client.force_authenticate(user=self.client_user)
        response = self.client.get("/api/agents/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        names = [r["first_name"] for r in response.data["results"]]
        self.assertIn("Kouassi", names)
        self.assertIn("Kouakou", names)

    def test_search_filters_by_name(self):
        self.client.force_authenticate(user=self.client_user)
        response = self.client.get("/api/agents/?search=Kouassi")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        names = [r["first_name"] for r in response.data["results"]]
        self.assertIn("Kouassi", names)
        self.assertNotIn("Kouakou", names)

    def test_search_filters_by_agency_name(self):
        self.client.force_authenticate(user=self.client_user)
        response = self.client.get("/api/agents/?search=ABC")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        names = [r["first_name"] for r in response.data["results"]]
        self.assertIn("Kouassi", names)
        self.assertNotIn("Kouakou", names)

    def test_list_excludes_clients(self):
        self.client.force_authenticate(user=self.client_user)
        response = self.client.get("/api/agents/")
        names = [r["first_name"] for r in response.data["results"]]
        self.assertNotIn("Client", names)

    def test_never_exposes_private_fields(self):
        self.client.force_authenticate(user=self.client_user)
        response = self.client.get("/api/agents/")
        for agent in response.data["results"]:
            self.assertNotIn("password", agent)
            self.assertNotIn("is_staff", agent)
            self.assertNotIn("is_superuser", agent)
            self.assertNotIn("token", agent)

    def test_exposes_only_expected_public_fields(self):
        self.client.force_authenticate(user=self.client_user)
        response = self.client.get("/api/agents/")
        agent = response.data["results"][0]
        expected = {
            "id", "first_name", "last_name", "photo", "phone",
            "agency_name", "description", "rating", "is_verified",
        }
        self.assertEqual(set(agent.keys()), expected)


class AgentProfileEditTests(APITestCase):
    """Section 1.3 (mission corrections UX) : PATCH /api/agent/profile/ —
    un agent peut modifier agence/whatsapp/description, jamais
    is_verified/rating (réservés à l'administration Django)."""

    def setUp(self):
        self.agent = _make_agent("+2250711115010", agency_name="Ancien nom")
        self.client_user = _make_client("+2250711115011")

    def test_agent_can_view_own_profile(self):
        self.client.force_authenticate(user=self.agent)
        response = self.client.get("/api/agent/profile/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["agency_name"], "Ancien nom")

    def test_agent_can_update_agency_whatsapp_description(self):
        self.client.force_authenticate(user=self.agent)
        response = self.client.patch(
            "/api/agent/profile/",
            {
                "agency_name": "Nouvelle agence",
                "whatsapp": "+2250700000000",
                "description": "Spécialiste Cocody",
            },
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.agent.agent_profile.refresh_from_db()
        self.assertEqual(self.agent.agent_profile.agency_name, "Nouvelle agence")
        self.assertEqual(self.agent.agent_profile.description, "Spécialiste Cocody")

    def test_agent_cannot_self_verify_or_self_rate(self):
        self.client.force_authenticate(user=self.agent)
        response = self.client.patch(
            "/api/agent/profile/",
            {"is_verified": True, "rating": 5.0},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.agent.agent_profile.refresh_from_db()
        self.assertFalse(self.agent.agent_profile.is_verified)
        self.assertEqual(float(self.agent.agent_profile.rating), 0.0)

    def test_client_cannot_access_agent_profile_endpoint(self):
        self.client.force_authenticate(user=self.client_user)
        response = self.client.get("/api/agent/profile/")
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_anonymous_cannot_access_agent_profile_endpoint(self):
        response = self.client.get("/api/agent/profile/")
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_certification_status_is_not_editable_via_this_endpoint(self):
        self.client.force_authenticate(user=self.agent)
        response = self.client.patch(
            "/api/agent/profile/",
            {"certification_status": AgentProfile.CERTIFICATION_APPROVED},
            format="json",
        )
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.agent.agent_profile.refresh_from_db()
        self.assertEqual(
            self.agent.agent_profile.certification_status,
            AgentProfile.CERTIFICATION_NOT_REQUESTED,
        )


class AgentCertificationRequestTests(APITestCase):
    """Décision métier retenue (mission de finalisation) :

        Agent → demande → EN_ATTENTE → Django Admin → approuvée/refusée

    Un agent ne peut jamais s'auto-certifier."""

    def setUp(self):
        self.agent = _make_agent("+2250711115020")
        self.other_agent = _make_agent("+2250711115021")
        self.bailleur = User.objects.create_user(
            phone="+2250711115022", password="secret123", first_name="Bl", last_name="B",
            role=User.ROLE_BAILLEUR,
        )
        self.client_user = _make_client("+2250711115023")

    def test_agent_can_request_certification(self):
        self.client.force_authenticate(user=self.agent)
        response = self.client.post("/api/agent/certification/request/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data["certification_status"], "en_attente")
        # La demande seule ne certifie jamais automatiquement.
        self.assertFalse(response.data["is_verified"])

        self.agent.agent_profile.refresh_from_db()
        self.assertEqual(
            self.agent.agent_profile.certification_status, AgentProfile.CERTIFICATION_PENDING
        )
        self.assertFalse(self.agent.agent_profile.is_verified)

    def test_cannot_request_twice_while_pending(self):
        self.client.force_authenticate(user=self.agent)
        self.client.post("/api/agent/certification/request/")
        second = self.client.post("/api/agent/certification/request/")
        self.assertEqual(second.status_code, status.HTTP_400_BAD_REQUEST)

    def test_cannot_request_again_once_already_approved(self):
        self.agent.agent_profile.certification_status = AgentProfile.CERTIFICATION_APPROVED
        self.agent.agent_profile.is_verified = True
        self.agent.agent_profile.save(update_fields=["certification_status", "is_verified"])

        self.client.force_authenticate(user=self.agent)
        response = self.client.post("/api/agent/certification/request/")
        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_bailleur_cannot_request_agent_certification(self):
        self.client.force_authenticate(user=self.bailleur)
        response = self.client.post("/api/agent/certification/request/")
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_client_cannot_request_agent_certification(self):
        self.client.force_authenticate(user=self.client_user)
        response = self.client.post("/api/agent/certification/request/")
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

    def test_admin_approve_action_sets_both_status_and_is_verified(self):
        self.agent.agent_profile.certification_status = AgentProfile.CERTIFICATION_PENDING
        self.agent.agent_profile.save(update_fields=["certification_status"])

        # Simule AgentProfileAdmin.approve_certification (queryset.update),
        # jamais l'agent lui-même.
        AgentProfile.objects.filter(pk=self.agent.pk).update(
            certification_status=AgentProfile.CERTIFICATION_APPROVED, is_verified=True
        )
        self.agent.agent_profile.refresh_from_db()
        self.assertEqual(
            self.agent.agent_profile.certification_status, AgentProfile.CERTIFICATION_APPROVED
        )
        self.assertTrue(self.agent.agent_profile.is_verified)

    def test_other_agent_cannot_approve_via_the_request_endpoint(self):
        """Il n'existe tout simplement aucun paramètre d'approbation sur cet
        endpoint — un autre agent (ou n'importe qui) ne peut au mieux que
        déclencher SA PROPRE demande, jamais approuver celle d'un tiers."""
        self.client.force_authenticate(user=self.other_agent)
        response = self.client.post("/api/agent/certification/request/")
        self.assertEqual(response.status_code, status.HTTP_200_OK)

        self.agent.agent_profile.refresh_from_db()
        self.assertEqual(
            self.agent.agent_profile.certification_status, AgentProfile.CERTIFICATION_NOT_REQUESTED
        )
