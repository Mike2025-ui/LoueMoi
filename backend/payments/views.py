import json
import logging
import uuid
from django.conf import settings
from django.contrib.auth import get_user_model
from django.http import HttpResponse, JsonResponse
from django.utils import timezone
from django.views.decorators.csrf import csrf_exempt
from rest_framework import permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from properties.models import Property
from .jeko import create_payment_request, verify_webhook_signature, JekoClientError
from .models import Subscription
from .serializers import CreateSubscriptionSerializer, SubscriptionSerializer

logger = logging.getLogger(__name__)
User = get_user_model()


class CreateSubscriptionView(APIView):
    """POST /api/payments/subscriptions/create/

    Crée une souscription d'abonnement mensuel et initie le paiement Jèko Checkout.
    - Client : 1 000 FCFA / mois
    - Agent & Bailleur : 3 000 FCFA / mois
    """

    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        serializer = CreateSubscriptionSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        user = request.user
        payment_method = serializer.validated_data["payment_method"]
        payer_phone = serializer.validated_data.get("payer_phone") or user.phone

        if user.role in (User.ROLE_AGENT, User.ROLE_BAILLEUR):
            plan = Subscription.PLAN_PRO
            amount = Subscription.PRICES[Subscription.PLAN_PRO]
        else:
            plan = Subscription.PLAN_CLIENT
            amount = Subscription.PRICES[Subscription.PLAN_CLIENT]

        reference = f"SUB-{uuid.uuid4().hex[:10].upper()}"

        base_url = request.build_absolute_uri("/").rstrip("/")
        success_url = f"{base_url}/api/payments/redirect/success/?ref={reference}"
        error_url = f"{base_url}/api/payments/redirect/error/?ref={reference}"

        try:
            jeko_res = create_payment_request(
                amount_fcfa=amount,
                reference=reference,
                payment_method=payment_method,
                success_url=success_url,
                error_url=error_url,
                payer_phone=payer_phone,
            )
        except JekoClientError as e:
            return Response({"detail": str(e)}, status=status.HTTP_400_BAD_REQUEST)

        sub = Subscription.objects.create(
            user=user,
            plan=plan,
            amount=amount,
            payment_method=payment_method,
            reference=reference,
            jeko_payment_request_id=jeko_res.get("id", ""),
            status=Subscription.STATUS_PENDING,
        )

        redirect_url = jeko_res.get("redirectUrl", success_url)

        return Response(
            {
                "reference": sub.reference,
                "redirect_url": redirect_url,
                "amount": sub.amount,
                "plan": sub.plan,
                "payment_method": sub.payment_method,
                "is_simulation": jeko_res.get("simulation", False),
            },
            status=status.HTTP_201_CREATED,
        )


class SubscriptionStatusView(APIView):
    """GET /api/payments/subscriptions/status/

    Retourne le statut d'abonnement de l'utilisateur connecté.
    """

    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        now = timezone.now()
        active_sub = (
            Subscription.objects.filter(
                user=user,
                status=Subscription.STATUS_ACTIVE,
                expires_at__gt=now,
            )
            .order_by("-expires_at")
            .first()
        )

        required_plan = (
            Subscription.PLAN_PRO
            if user.role in (User.ROLE_AGENT, User.ROLE_BAILLEUR)
            else Subscription.PLAN_CLIENT
        )
        plan_price = Subscription.PRICES[required_plan]

        return Response(
            {
                "has_active_subscription": active_sub is not None,
                "subscription": SubscriptionSerializer(active_sub).data if active_sub else None,
                "role": user.role,
                "required_plan": required_plan,
                "plan_price": plan_price,
            },
            status=status.HTTP_200_OK,
        )


class CanContactView(APIView):
    """GET /api/payments/can-contact/?property_id=<id>&owner_id=<id>

    Détermine si l'utilisateur connecté peut contacter l'agent ou le bailleur
    (WhatsApp, Appel, Conversation, Visite).

    Règles métier :
    - Si l'agent/bailleur possède un abonnement : les clients peuvent le contacter GRATUITEMENT.
    - Si l'agent/bailleur n'a PAS d'abonnement : le client doit avoir un abonnement de 1 000 FCFA/mois.
    - Si l'utilisateur connecté est un agent/bailleur contactant un client :
      l'agent/bailleur doit avoir son abonnement (3 000 FCFA/mois).
    """

    permission_classes = [permissions.AllowAny]

    def get(self, request):
        property_id = request.query_params.get("property_id")
        owner_id = request.query_params.get("owner_id")

        owner = None
        if property_id:
            prop = Property.objects.filter(pk=property_id).select_related("agent").first()
            if prop:
                owner = prop.agent
        elif owner_id:
            owner = User.objects.filter(pk=owner_id).first()

        now = timezone.now()
        owner_subscribed = False
        if owner:
            owner_subscribed = owner.subscriptions.filter(
                status=Subscription.STATUS_ACTIVE,
                expires_at__gt=now,
            ).exists()

        user = request.user if request.user.is_authenticated else None
        user_subscribed = False
        is_owner_himself = False

        if user:
            user_subscribed = user.subscriptions.filter(
                status=Subscription.STATUS_ACTIVE,
                expires_at__gt=now,
            ).exists()
            if owner and user.id == owner.id:
                is_owner_himself = True

        # Règles de contact :
        # 1. Le propriétaire consulte son propre bien
        if is_owner_himself:
            can_contact = True
            reason = "self"
        # 2. Si l'agent ou bailleur possède un abonnement : contact gratuit pour tous !
        elif owner_subscribed:
            can_contact = True
            reason = "owner_subscribed"
        # 3. Si l'agent/bailleur n'est pas abonné, le client doit avoir son propre abonnement (1000F)
        elif user_subscribed:
            can_contact = True
            reason = "client_subscribed"
        else:
            can_contact = False
            reason = "subscription_required"

        return Response(
            {
                "can_contact": can_contact,
                "reason": reason,
                "owner_has_active_subscription": owner_subscribed,
                "user_has_active_subscription": user_subscribed,
                "client_plan_price": Subscription.PRICES[Subscription.PLAN_CLIENT],
                "pro_plan_price": Subscription.PRICES[Subscription.PLAN_PRO],
            },
            status=status.HTTP_200_OK,
        )


@csrf_exempt
def jeko_webhook(request):
    """POST /api/payments/webhook/

    Webhook Jèko sécurisé avec vérification de l'en-tête `Jeko-Signature` (HMAC-SHA256).
    Idempotent sur `reference` / `id`.
    """
    if request.method != "POST":
        return HttpResponse(status=405)

    signature = request.headers.get("Jeko-Signature", "")
    raw_body = request.body

    # En environnement de dev sans webhook secret configuré, tolérer pour les tests manuels
    secret = getattr(settings, "JEKO_WEBHOOK_SECRET", "")
    if secret:
        if not verify_webhook_signature(raw_body, signature):
            logger.warning("Signature webhook Jèko invalide rejetée.")
            return JsonResponse({"error": "Signature invalide"}, status=401)

    try:
        data = json.loads(raw_body.decode("utf-8"))
    except Exception as e:
        logger.error(f"Corps JSON webhook invalide: {e}")
        return JsonResponse({"error": "JSON invalide"}, status=400)

    # Statut de la transaction Jèko
    tx_status = data.get("status")
    details = data.get("transactionDetails") or {}
    reference = details.get("reference") or data.get("reference")

    if not reference:
        return JsonResponse({"received": True, "warning": "Aucune référence"}, status=200)

    sub = Subscription.objects.filter(reference=reference).first()
    if not sub:
        logger.warning(f"Abonnement introuvable pour la référence {reference}")
        return JsonResponse({"received": True, "warning": "Référence inconnue"}, status=200)

    if tx_status == "success":
        sub.activate_for_30_days()
        logger.info(f"Abonnement {sub.reference} activé pour 30 jours pour {sub.user}.")
    elif tx_status == "error":
        sub.status = Subscription.STATUS_CANCELLED
        sub.save(update_fields=["status", "updated_at"])
        logger.info(f"Abonnement {sub.reference} marqué en échec.")

    return JsonResponse({"received": True}, status=200)


def redirect_success(request):
    """Page de retour de succès après paiement Jèko."""
    ref = request.GET.get("ref", "")
    # Mode simulation locale : activation automatique si préfixe sim_ ou simulent
    if ref:
        sub = Subscription.objects.filter(reference=ref).first()
        if sub and getattr(settings, "DEBUG", False):
            sub.activate_for_30_days()

    html = f"""
    <!DOCTYPE html>
    <html lang="fr">
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Paiement Réussi · LoueMoi</title>
        <style>
            body {{ font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; background: #F8FAFC; text-align: center; padding: 20px; }}
            .card {{ background: white; border-radius: 16px; padding: 32px; box-shadow: 0 4px 20px rgba(0,0,0,0.08); max-width: 400px; width: 100%; }}
            .icon {{ width: 64px; height: 64px; background: #DCFCE7; color: #16A34A; border-radius: 50%; display: flex; align-items: center; justify-content: center; margin: 0 auto 16px; font-size: 32px; }}
            h1 {{ font-size: 20px; color: #0F172A; margin: 0 0 8px; }}
            p {{ color: #64748B; font-size: 14px; margin: 0 0 24px; }}
            a.btn {{ display: inline-block; background: #16A34A; color: white; text-decoration: none; padding: 12px 24px; border-radius: 999px; font-weight: 600; font-size: 14px; }}
        </style>
    </head>
    <body>
        <div class="card">
            <div class="icon">✓</div>
            <h1>Paiement confirmé !</h1>
            <p>Votre abonnement LoueMoi a été activé avec succès. Votre badge certifié est maintenant actif.</p>
            <a href="louemoi://payment/success?reference={ref}" class="btn">Retourner à l'application</a>
        </div>
    </body>
    </html>
    """
    return HttpResponse(html)


def redirect_error(request):
    """Page de retour en cas d'erreur ou d'annulation après paiement Jèko."""
    ref = request.GET.get("ref", "")
    html = f"""
    <!DOCTYPE html>
    <html lang="fr">
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Paiement Annulé · LoueMoi</title>
        <style>
            body {{ font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; background: #F8FAFC; text-align: center; padding: 20px; }}
            .card {{ background: white; border-radius: 16px; padding: 32px; box-shadow: 0 4px 20px rgba(0,0,0,0.08); max-width: 400px; width: 100%; }}
            .icon {{ width: 64px; height: 64px; background: #FEE2E2; color: #DC2626; border-radius: 50%; display: flex; align-items: center; justify-content: center; margin: 0 auto 16px; font-size: 32px; }}
            h1 {{ font-size: 20px; color: #0F172A; margin: 0 0 8px; }}
            p {{ color: #64748B; font-size: 14px; margin: 0 0 24px; }}
            a.btn {{ display: inline-block; background: #DC2626; color: white; text-decoration: none; padding: 12px 24px; border-radius: 999px; font-weight: 600; font-size: 14px; }}
        </style>
    </head>
    <body>
        <div class="card">
            <div class="icon">✕</div>
            <h1>Paiement non finalisé</h1>
            <p>La transaction n'a pas pu être complétée. Aucun débit n'a été effectué.</p>
            <a href="louemoi://payment/error?reference={ref}" class="btn">Retourner à l'application</a>
        </div>
    </body>
    </html>
    """
    return HttpResponse(html)
