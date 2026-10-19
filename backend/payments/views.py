import json
import logging
import uuid
from django.conf import settings
from django.contrib.auth import get_user_model
from django.http import HttpResponse, HttpResponseRedirect, JsonResponse
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
        web_app_url = getattr(settings, "WEB_APP_URL", "https://transfert-online.site").rstrip("/")
        success_url = f"{web_app_url}/?payment=success&ref={reference}"
        error_url = f"{web_app_url}/?payment=error&ref={reference}"
        checkout_url = f"{base_url}/api/payments/checkout/simulate/?ref={reference}"

        try:
            jeko_res = create_payment_request(
                amount_fcfa=amount,
                reference=reference,
                payment_method=payment_method,
                success_url=success_url,
                error_url=error_url,
                payer_phone=payer_phone,
                checkout_url=checkout_url,
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

        redirect_url = (
            jeko_res.get("redirectUrl")
            or jeko_res.get("paymentDetails", {}).get("data", {}).get("redirectUrl")
            or jeko_res.get("paymentDetails", {}).get("data", {}).get("paymentUrl")
            or jeko_res.get("url")
            or success_url
        )

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

        # Nettoyage temps réel des abonnements actifs qui viennent d'expirer
        expired_active_subs = Subscription.objects.filter(
            user=user,
            status=Subscription.STATUS_ACTIVE,
            expires_at__lte=now,
        )
        for s in expired_active_subs:
            s.expire_and_revoke()

        active_sub = (
            Subscription.objects.filter(
                user=user,
                status=Subscription.STATUS_ACTIVE,
                expires_at__gt=now,
            )
            .order_by("-expires_at")
            .first()
        )

        days_remaining = active_sub.days_remaining if active_sub else 0
        expiring_soon = False

        if active_sub and days_remaining <= 5:
            expiring_soon = True
            if not active_sub.expiry_warning_sent:
                from notifications.models import Notification
                from notifications.services import NotificationService

                expiry_str = active_sub.expires_at.strftime("%d/%m/%Y")
                NotificationService.notify(
                    recipient=user,
                    notif_type=Notification.TYPE_SUBSCRIPTION_EXPIRING,
                    title="Abonnement expirant bientôt",
                    body=(
                        f"Votre abonnement LoueMoi expire dans {days_remaining} jour(s) (le {expiry_str}). "
                        "Renouvelez-le dès maintenant pour conserver vos accès et votre badge vérifié."
                    ),
                    data={
                        "type": "subscription_expiring",
                        "subscription_id": active_sub.id,
                        "reference": active_sub.reference,
                    },
                )
                active_sub.expiry_warning_sent = True
                active_sub.save(update_fields=["expiry_warning_sent"])

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
                "days_remaining": days_remaining,
                "is_expiring_soon": expiring_soon,
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
            try:
                prop = Property.objects.filter(pk=property_id).select_related("agent").first()
                if prop:
                    owner = prop.agent
            except Exception:
                pass
        elif owner_id:
            try:
                owner = User.objects.filter(pk=owner_id).first()
            except Exception:
                pass

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
    Idempotent sur `reference` / `id`. Insensible à la casse sur les statuts.
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

    # Statut de la transaction Jèko (normalisation minuscule)
    tx_status = (data.get("status") or "").strip().lower()
    details = data.get("transactionDetails") or data.get("paymentDetails") or {}
    reference = details.get("reference") or data.get("reference") or data.get("orderId")
    payment_request_id = data.get("id") or details.get("id")

    sub = None
    if reference:
        sub = Subscription.objects.filter(reference=reference).first()
    if not sub and payment_request_id:
        sub = Subscription.objects.filter(jeko_payment_request_id=payment_request_id).first()

    if not sub:
        logger.warning(f"Abonnement introuvable pour la référence {reference} / id {payment_request_id}")
        return JsonResponse({"received": True, "warning": "Référence inconnue"}, status=200)

    if tx_status in ("success", "successful", "completed", "paid"):
        sub.activate_for_30_days()
        logger.info(f"Abonnement {sub.reference} activé pour 30 jours pour {sub.user}.")
    elif tx_status in ("error", "failed", "cancelled", "canceled"):
        sub.status = Subscription.STATUS_CANCELLED
        sub.save(update_fields=["status", "updated_at"])
        logger.info(f"Abonnement {sub.reference} marqué en échec.")

    return JsonResponse({"received": True}, status=200)


def simulate_checkout(request):
    """Portail de simulation de paiement Mobile Money.

    Ne valide JAMAIS un paiement automatiquement : l'utilisateur doit
    explicitement confirmer la transaction avant qu'elle ne soit validée.
    Après confirmation ou annulation, l'utilisateur est redirigé vers l'application web.
    """
    ref = request.GET.get("ref", "")
    sub = Subscription.objects.filter(reference=ref).first()
    web_app_url = getattr(settings, "WEB_APP_URL", "https://transfert-online.site").rstrip("/")

    if not sub:
        return HttpResponseRedirect(f"{web_app_url}/?payment=error&reason=not_found")

    action = request.POST.get("action") or request.GET.get("action")
    if action == "confirm":
        sub.activate_for_30_days()
        logger.info(f"[Simulation] Paiement confirmé pour {sub.reference}. Abonnement activé.")
        return HttpResponseRedirect(f"{web_app_url}/?payment=success&ref={ref}")
    elif action == "cancel":
        sub.status = Subscription.STATUS_CANCELLED
        sub.save(update_fields=["status", "updated_at"])
        logger.info(f"[Simulation] Paiement annulé pour {sub.reference}.")
        return HttpResponseRedirect(f"{web_app_url}/?payment=cancelled&ref={ref}")

    method_labels = {
        "wave": ("Wave", "#1BA4D9", "#FFFFFF"),
        "orange": ("Orange Money", "#FF7900", "#FFFFFF"),
        "mtn": ("MTN MoMo", "#FFCC00", "#000000"),
        "moov": ("Moov Money", "#005CA9", "#FFFFFF"),
    }
    method_name, method_color, method_text_color = method_labels.get(
        sub.payment_method, ("Mobile Money", "#007AFF", "#FFFFFF")
    )
    plan_name = "Bailleur / Agent" if sub.plan == Subscription.PLAN_PRO else "Client"

    html = f"""
    <!DOCTYPE html>
    <html lang="fr">
    <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Paiement {method_name} · LoueMoi</title>
        <style>
            body {{ font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; display: flex; align-items: center; justify-content: center; min-height: 100vh; margin: 0; background: #F1F5F9; padding: 20px; box-sizing: border-box; }}
            .card {{ background: white; border-radius: 20px; padding: 32px; box-shadow: 0 10px 30px rgba(0,0,0,0.08); max-width: 420px; width: 100%; text-align: center; }}
            .header-tag {{ display: inline-block; background: #EEF2F6; color: #475569; font-size: 12px; font-weight: 600; padding: 4px 12px; border-radius: 999px; margin-bottom: 16px; }}
            .badge-op {{ width: 64px; height: 64px; border-radius: 16px; background: {method_color}; color: {method_text_color}; display: flex; align-items: center; justify-content: center; font-size: 24px; font-weight: 800; margin: 0 auto 16px; }}
            h1 {{ font-size: 22px; color: #0F172A; margin: 0 0 6px; }}
            .amount {{ font-size: 28px; font-weight: 800; color: #0F172A; margin: 12px 0 20px; }}
            .details {{ background: #F8FAFC; border: 1px solid #E2E8F0; border-radius: 12px; padding: 14px 18px; margin-bottom: 24px; text-align: left; font-size: 14px; }}
            .details-row {{ display: flex; justify-content: space-between; margin-bottom: 8px; color: #64748B; }}
            .details-row:last-child {{ margin-bottom: 0; }}
            .details-val {{ font-weight: 600; color: #1E293B; }}
            .btn-confirm {{ display: block; width: 100%; background: {method_color}; color: {method_text_color}; border: none; padding: 14px 20px; border-radius: 12px; font-weight: 700; font-size: 16px; cursor: pointer; text-decoration: none; box-sizing: border-box; margin-bottom: 10px; }}
            .btn-cancel {{ display: block; width: 100%; background: #F1F5F9; color: #64748B; border: none; padding: 12px 20px; border-radius: 12px; font-weight: 600; font-size: 14px; cursor: pointer; text-decoration: none; box-sizing: border-box; }}
        </style>
    </head>
    <body>
        <div class="card">
            <span class="header-tag">Portail de Paiement Mobile Money</span>
            <div class="badge-op">{method_name[:2].upper()}</div>
            <h1>Abonnement LoueMoi</h1>
            <div class="amount">{sub.amount:,} FCFA</div>
            <div class="details">
                <div class="details-row"><span>Formule :</span><span class="details-val">{plan_name}</span></div>
                <div class="details-row"><span>Moyen :</span><span class="details-val">{method_name}</span></div>
                <div class="details-row"><span>Téléphone :</span><span class="details-val">{sub.user.phone}</span></div>
                <div class="details-row"><span>Référence :</span><span class="details-val">{sub.reference}</span></div>
            </div>
            <a href="?ref={ref}&action=confirm" class="btn-confirm">Payer</a>
            <a href="?ref={ref}&action=cancel" class="btn-cancel">Annuler la transaction</a>
        </div>
    </body>
    </html>
    """
    return HttpResponse(html)


def redirect_success(request):
    """Redirection après paiement validé vers l'application web."""
    ref = request.GET.get("ref", "")
    web_app_url = getattr(settings, "WEB_APP_URL", "https://transfert-online.site").rstrip("/")
    return HttpResponseRedirect(f"{web_app_url}/?payment=success&ref={ref}")


def redirect_error(request):
    """Redirection en cas d'erreur ou d'annulation vers l'application web."""
    ref = request.GET.get("ref", "")
    web_app_url = getattr(settings, "WEB_APP_URL", "https://transfert-online.site").rstrip("/")
    return HttpResponseRedirect(f"{web_app_url}/?payment=error&ref={ref}")

