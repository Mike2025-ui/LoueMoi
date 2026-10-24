import json
from datetime import timedelta
from django.contrib.auth import get_user_model
from django.test import TestCase
from django.utils import timezone
from rest_framework.test import APIClient

from agents.models import AgentProfile
from payments.models import Subscription
from properties.models import Property
from reservations.models import Reservation

User = get_user_model()


class PaymentAndContactRulesTestCase(TestCase):
    def setUp(self):
        self.client = APIClient()

        # Agent avec profil
        self.agent = User.objects.create_user(
            phone="+2250101010101",
            first_name="Agent",
            last_name="Pro",
            role=User.ROLE_AGENT,
            password="password123",
        )
        self.agent_profile = AgentProfile.objects.create(
            user=self.agent,
            agency_name="Agence Pro",
            is_verified=False,
        )

        # Bailleur
        self.bailleur = User.objects.create_user(
            phone="+2250202020202",
            first_name="Bailleur",
            last_name="Immo",
            role=User.ROLE_BAILLEUR,
            password="password123",
        )

        # Client non abonné
        self.client_user = User.objects.create_user(
            phone="+2250303030303",
            first_name="Client",
            last_name="Standard",
            role=User.ROLE_CLIENT,
            password="password123",
        )

        # Propriété de l'agent
        self.prop = Property.objects.create(
            agent=self.agent,
            title="Studio Riviera",
            description="Beau studio",
            type="studio",
            transaction_type="rent",
            price=150000,
            city="Abidjan",
            commune="Cocody",
            district="Riviera",
            address="Rue des Jardins",
            latitude=5.348,
            longitude=-3.989,
            status="disponible",
        )

    def test_create_subscription_prices(self):
        # Client : 1000 FCFA
        self.client.force_authenticate(user=self.client_user)
        res_client = self.client.post(
            "/api/payments/subscriptions/create/",
            {"payment_method": "wave"},
            format="json",
        )
        self.assertEqual(res_client.status_code, 201)
        self.assertEqual(res_client.data["amount"], 1000)
        self.assertEqual(res_client.data["plan"], "client")

        # Agent : 3000 FCFA
        self.client.force_authenticate(user=self.agent)
        res_agent = self.client.post(
            "/api/payments/subscriptions/create/",
            {"payment_method": "orange"},
            format="json",
        )
        self.assertEqual(res_agent.status_code, 201)
        self.assertEqual(res_agent.data["amount"], 3000)
        self.assertEqual(res_agent.data["plan"], "pro")

    def test_automatic_verification_badge_on_subscription(self):
        # Agent non vérifié au départ
        self.assertFalse(self.agent.is_verified)
        self.assertFalse(self.agent.agent_profile.is_verified)

        sub = Subscription.objects.create(
            user=self.agent,
            plan=Subscription.PLAN_PRO,
            amount=3000,
            reference="SUB-AGENT-TEST",
            payment_method="wave",
            status=Subscription.STATUS_PENDING,
        )
        sub.activate_for_30_days()

        self.agent.refresh_from_db()
        self.agent_profile.refresh_from_db()
        self.assertTrue(self.agent.is_verified)
        self.assertTrue(self.agent_profile.is_verified)
        self.assertTrue(self.agent.has_active_subscription)

    def test_contact_gating_rules(self):
        # 1. Agent non abonné, Client non abonné => Contact BLOQUÉ
        self.client.force_authenticate(user=self.client_user)
        res = self.client.get(f"/api/payments/can-contact/?property_id={self.prop.id}")
        self.assertEqual(res.status_code, 200)
        self.assertFalse(res.data["can_contact"])
        self.assertEqual(res.data["reason"], "subscription_required")

        # 2. Client s'abonne => Contact AUTORISÉ (client_subscribed)
        client_sub = Subscription.objects.create(
            user=self.client_user,
            plan=Subscription.PLAN_CLIENT,
            amount=1000,
            reference="SUB-CLIENT-TEST",
            status=Subscription.STATUS_PENDING,
        )
        client_sub.activate_for_30_days()

        res2 = self.client.get(f"/api/payments/can-contact/?property_id={self.prop.id}")
        self.assertEqual(res2.status_code, 200)
        self.assertTrue(res2.data["can_contact"])
        self.assertEqual(res2.data["reason"], "client_subscribed")

        # 3. Agent s'abonne => Contact GRATUIT pour TOUS (même sans abonnement client)
        client_sub.status = Subscription.STATUS_EXPIRED
        client_sub.expires_at = timezone.now() - timedelta(days=1)
        client_sub.save()

        agent_sub = Subscription.objects.create(
            user=self.agent,
            plan=Subscription.PLAN_PRO,
            amount=3000,
            reference="SUB-AGENT-TEST2",
            status=Subscription.STATUS_PENDING,
        )
        agent_sub.activate_for_30_days()

        # Client non abonné réessaye
        res3 = self.client.get(f"/api/payments/can-contact/?property_id={self.prop.id}")
        self.assertEqual(res3.status_code, 200)
        self.assertTrue(res3.data["can_contact"])
        self.assertEqual(res3.data["reason"], "owner_subscribed")

    def test_property_deletion_blocked_if_reservation_en_cours(self):
        # Réservation en cours sur la propriété
        resv = Reservation.objects.create(
            user=self.client_user,
            property=self.prop,
            rent=150000,
            deposit=150000,
            advance=150000,
            status="enCours",
        )

        self.client.force_authenticate(user=self.agent)
        del_res = self.client.delete(f"/api/properties/{self.prop.id}/")
        # Doit être refusé
        self.assertEqual(del_res.status_code, 400)
        self.assertIn("en cours", del_res.data["detail"])
        self.assertTrue(Property.objects.filter(id=self.prop.id).exists())

        # Si accomplie : suppression autorisée
        resv.status = "accomplie"
        resv.save()
        del_res_ok = self.client.delete(f"/api/properties/{self.prop.id}/")
        self.assertEqual(del_res_ok.status_code, 204)
        self.assertFalse(Property.objects.filter(id=self.prop.id).exists())

    def test_client_badge_and_expiration_revocation(self):
        from accounts.serializers import UserSerializer

        # 1. Client non abonné : pas de badge
        self.assertFalse(UserSerializer(self.client_user).data["is_verified"])
        self.assertFalse(self.client_user.has_active_subscription)

        # 2. Client s'abonne : badge activé
        sub = Subscription.objects.create(
            user=self.client_user,
            plan=Subscription.PLAN_CLIENT,
            amount=1000,
            reference="SUB-CLI-REVOKE",
            status=Subscription.STATUS_PENDING,
        )
        sub.activate_for_30_days()
        self.client_user.refresh_from_db()
        self.assertTrue(self.client_user.has_active_subscription)
        self.assertTrue(UserSerializer(self.client_user).data["is_verified"])

        # 3. Expiration : badge révoqué
        sub.expire_and_revoke()
        self.client_user.refresh_from_db()
        self.assertFalse(self.client_user.has_active_subscription)
        self.assertFalse(UserSerializer(self.client_user).data["is_verified"])

    def test_check_expirations_management_command(self):
        from django.core.management import call_command
        from notifications.models import Notification

        # Sub 1 : expire dans 3 jours (doit recevoir l'alerte 5 jours)
        sub_warn = Subscription.objects.create(
            user=self.bailleur,
            plan=Subscription.PLAN_PRO,
            amount=3000,
            reference="SUB-WARN-5D",
            status=Subscription.STATUS_ACTIVE,
            started_at=timezone.now() - timedelta(days=25),
            expires_at=timezone.now() + timedelta(days=3),
            expiry_warning_sent=False,
        )

        # Sub 2 : déjà expiré
        sub_exp = Subscription.objects.create(
            user=self.agent,
            plan=Subscription.PLAN_PRO,
            amount=3000,
            reference="SUB-ALREADY-EXP",
            status=Subscription.STATUS_ACTIVE,
            started_at=timezone.now() - timedelta(days=31),
            expires_at=timezone.now() - timedelta(hours=2),
        )
        self.agent.is_verified = True
        self.agent.save()

        call_command("check_expirations")

        sub_warn.refresh_from_db()
        self.assertTrue(sub_warn.expiry_warning_sent)
        self.assertTrue(
            Notification.objects.filter(
                recipient=self.bailleur,
                type=Notification.TYPE_SUBSCRIPTION_EXPIRING,
            ).exists()
        )

        sub_exp.refresh_from_db()
        self.assertEqual(sub_exp.status, Subscription.STATUS_EXPIRED)
        self.agent.refresh_from_db()
        self.assertFalse(self.agent.is_verified)
        self.assertTrue(
            Notification.objects.filter(
                recipient=self.agent,
                type=Notification.TYPE_SUBSCRIPTION_EXPIRED,
            ).exists()
        )

    def test_simulation_checkout_and_web_redirect(self):
        sub = Subscription.objects.create(
            user=self.agent,
            plan=Subscription.PLAN_PRO,
            amount=3000,
            payment_method="wave",
            reference="SUB-SIM-CHECKOUT",
            status=Subscription.STATUS_PENDING,
        )

        # 1. Visite du portail de test : ne confirme pas automatiquement
        res_portal = self.client.get(f"/api/payments/checkout/simulate/?ref={sub.reference}")
        self.assertEqual(res_portal.status_code, 200)
        self.assertIn("Abonnement LoueMoi", res_portal.content.decode("utf-8"))
        sub.refresh_from_db()
        self.assertEqual(sub.status, Subscription.STATUS_PENDING)

        # 2. Confirmation explicite : active et redirige vers transfert-online.site
        res_confirm = self.client.get(
            f"/api/payments/checkout/simulate/?ref={sub.reference}&action=confirm"
        )
        self.assertEqual(res_confirm.status_code, 302)
        self.assertIn("https://transfert-online.site/?payment=success", res_confirm.url)
        sub.refresh_from_db()
        self.assertEqual(sub.status, Subscription.STATUS_ACTIVE)
        self.agent.refresh_from_db()
        self.assertTrue(self.agent.is_verified)

        # 3. Redirection direct success : redirige vers transfert-online.site
        res_succ = self.client.get(f"/api/payments/redirect/success/?ref={sub.reference}")
        self.assertEqual(res_succ.status_code, 302)
        self.assertIn("https://transfert-online.site/?payment=success", res_succ.url)

    def test_cumulative_renewal_does_not_lose_remaining_days(self):
        # 1. Abonnement initial avec 10 jours restants
        initial_sub = Subscription.objects.create(
            user=self.agent,
            plan=Subscription.PLAN_PRO,
            amount=3000,
            reference="SUB-INIT-10D",
            status=Subscription.STATUS_ACTIVE,
            started_at=timezone.now() - timedelta(days=20),
            expires_at=timezone.now() + timedelta(days=10),
        )

        # 2. Renouvellement : nouvel abonnement souscrit
        renewal_sub = Subscription.objects.create(
            user=self.agent,
            plan=Subscription.PLAN_PRO,
            amount=3000,
            reference="SUB-RENEW-30D",
            status=Subscription.STATUS_PENDING,
        )
        renewal_sub.activate_for_30_days()

        # Doit expirer dans ~40 jours (10 jours restants + 30 jours)
        diff_days = (renewal_sub.expires_at - timezone.now()).days
        self.assertGreaterEqual(diff_days, 39)
        self.assertLessEqual(diff_days, 41)

    def test_webhook_status_variants_and_request_id(self):
        sub = Subscription.objects.create(
            user=self.client_user,
            plan=Subscription.PLAN_CLIENT,
            amount=1000,
            reference="SUB-WEBHOOK-VAR",
            jeko_payment_request_id="jeko_req_999",
            status=Subscription.STATUS_PENDING,
        )

        # Webhook utilisant payment_request_id et statut en majuscule "SUCCESS"
        payload = {
            "id": "jeko_req_999",
            "status": "SUCCESS",
            "paymentDetails": {
                "reference": "SUB-WEBHOOK-VAR",
            },
        }
        res = self.client.post(
            "/api/payments/webhook/",
            data=json.dumps(payload),
            content_type="application/json",
        )
        self.assertEqual(res.status_code, 200)
        sub.refresh_from_db()
        self.assertEqual(sub.status, Subscription.STATUS_ACTIVE)

    def test_can_contact_invalid_property_id_resilience(self):
        # Ne doit pas lever de ValueError ou 500 sur un identifiant non numérique
        res = self.client.get("/api/payments/can-contact/?property_id=invalid_id_not_int")
        self.assertEqual(res.status_code, 200)
        self.assertFalse(res.data["can_contact"])

    def test_jeko_mobile_money_initiated_waiting_page_and_polling_redirect(self):
        sub = Subscription.objects.create(
            user=self.bailleur,
            plan=Subscription.PLAN_PRO,
            amount=5000,
            payment_method="orange",
            reference="SUB-MOMO-INIT",
            status=Subscription.STATUS_PENDING,
        )

        # 1. Après saisie du numéro sur Jèko Mobile Money, jeko_return affiche la page officielle "Paiement initié"
        res_init = self.client.get(f"/api/payments/jeko/return/?ref={sub.reference}&result=success")
        self.assertEqual(res_init.status_code, 200)
        html_body = res_init.content.decode("utf-8")
        self.assertIn("Paiement initié avec succès", html_body)
        self.assertIn(sub.reference, html_body)

        # 2. Tant que le paiement est en attente de validation sur le téléphone, check=1 retourne pending
        res_poll_pending = self.client.get(f"/api/payments/jeko/return/?ref={sub.reference}&check=1")
        self.assertEqual(res_poll_pending.status_code, 200)
        self.assertEqual(res_poll_pending.json()["status"], "pending")

        # 3. Dès que le paiement est finalisé (webhook ou confirmation), check=1 retourne active + redirect_url vers l'app Web
        sub.activate_for_30_days()
        res_poll_active = self.client.get(f"/api/payments/jeko/return/?ref={sub.reference}&check=1")
        self.assertEqual(res_poll_active.status_code, 200)
        data = res_poll_active.json()
        self.assertEqual(data["status"], "active")
        self.assertIn("https://transfert-online.site/?payment=success&ref=SUB-MOMO-INIT", data["redirect_url"])



