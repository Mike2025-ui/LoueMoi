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
from .jeko import (
    create_payment_request,
    verify_webhook_signature,
    get_payment_request_status,
    extract_jeko_status,
    is_jeko_status_success,
    is_jeko_status_failed,
    JekoClientError,
)
from .models import Subscription
from .serializers import CreateSubscriptionSerializer, SubscriptionSerializer

logger = logging.getLogger(__name__)
User = get_user_model()


def sync_user_pending_subscriptions(user):
    """Vérifie auprès de l'API Jèko tous les abonnements en attente récents de l'utilisateur
    et active automatiquement l'abonnement + le badge si le paiement est confirmé."""
    if not user or not getattr(user, "is_authenticated", False):
        return None

    now = timezone.now()

    # Nettoyage temps réel des abonnements actifs qui viennent d'expirer
    expired_active_subs = Subscription.objects.filter(
        user=user,
        status=Subscription.STATUS_ACTIVE,
        expires_at__lte=now,
    )
    for s in expired_active_subs:
        s.expire_and_revoke()

    # Vérifier les 5 derniers abonnements en attente auprès de Jèko
    pending_subs = Subscription.objects.filter(
        user=user,
        status=Subscription.STATUS_PENDING,
    ).order_by("-created_at")[:5]

    for pending in pending_subs:
        if pending.jeko_payment_request_id:
            jeko_data = get_payment_request_status(pending.jeko_payment_request_id)
            if jeko_data:
                tx_status = extract_jeko_status(jeko_data)
                if is_jeko_status_success(tx_status):
                    pending.activate_for_30_days()
                    logger.info(
                        f"Abonnement {pending.reference} validé via synchronisation Jèko."
                    )
                    break
                elif is_jeko_status_failed(tx_status):
                    pending.status = Subscription.STATUS_CANCELLED
                    pending.save(update_fields=["status", "updated_at"])

    active_sub = (
        Subscription.objects.filter(
            user=user,
            status=Subscription.STATUS_ACTIVE,
            expires_at__gt=now,
        )
        .order_by("-expires_at")
        .first()
    )

    if active_sub and not user.is_verified:
        user.is_verified = True
        user.save(update_fields=["is_verified"])
        if hasattr(user, "agent_profile"):
            user.agent_profile.is_verified = True
            user.agent_profile.save(update_fields=["is_verified"])

    return active_sub


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

        if user.role in (User.ROLE_AGENT, User.ROLE_BAILLEUR):
            plan = Subscription.PLAN_PRO
            amount = Subscription.PRICES[Subscription.PLAN_PRO]
        else:
            plan = Subscription.PLAN_CLIENT
            amount = Subscription.PRICES[Subscription.PLAN_CLIENT]

        reference = f"SUB-{uuid.uuid4().hex[:10].upper()}"

        base_url = request.build_absolute_uri("/").rstrip("/")
        success_url = f"{base_url}/api/payments/jeko/return/?ref={reference}&result=success"
        error_url = f"{base_url}/api/payments/jeko/return/?ref={reference}&result=error"
        checkout_url = f"{base_url}/api/payments/checkout/simulate/?ref={reference}"

        try:
            jeko_res = create_payment_request(
                amount_fcfa=amount,
                reference=reference,
                payment_method=payment_method,
                success_url=success_url,
                error_url=error_url,
                checkout_url=checkout_url,
            )
        except JekoClientError as e:
            return Response({"detail": str(e)}, status=status.HTTP_400_BAD_REQUEST)

        jeko_id = str(
            jeko_res.get("id")
            or (jeko_res.get("data") or {}).get("id")
            or (jeko_res.get("paymentRequest") or {}).get("id")
            or (jeko_res.get("paymentDetails") or {}).get("id")
            or ""
        )

        sub = Subscription.objects.create(
            user=user,
            plan=plan,
            amount=amount,
            payment_method=payment_method,
            reference=reference,
            jeko_payment_request_id=jeko_id,
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
        active_sub = sync_user_pending_subscriptions(user)

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
            sync_user_pending_subscriptions(owner)
            owner_subscribed = owner.subscriptions.filter(
                status=Subscription.STATUS_ACTIVE,
                expires_at__gt=now,
            ).exists()

        user = request.user if request.user.is_authenticated else None
        user_subscribed = False
        is_owner_himself = False

        if user:
            sync_user_pending_subscriptions(user)
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
    tx_status = extract_jeko_status(data)
    details = data.get("transactionDetails") or data.get("paymentDetails") or data.get("data") or {}
    reference = details.get("reference") or data.get("reference") or data.get("orderId")
    payment_request_id = data.get("id") or details.get("id") or data.get("paymentRequestId")

    sub = None
    if reference:
        sub = Subscription.objects.filter(reference=reference).first()
    if not sub and payment_request_id:
        sub = Subscription.objects.filter(jeko_payment_request_id=payment_request_id).first()

    if not sub:
        logger.warning(f"Abonnement introuvable pour la référence {reference} / id {payment_request_id}")
        return JsonResponse({"received": True, "warning": "Référence inconnue"}, status=200)

    if is_jeko_status_success(tx_status):
        # Défense en profondeur : si JEKO_WEBHOOK_SECRET n'est pas configuré mais que les clés API Jèko
        # sont présentes en production, vérifier l'état réel de la transaction auprès de l'API Jèko.
        has_jeko_keys = bool(getattr(settings, "JEKO_API_KEY", "") and getattr(settings, "JEKO_API_KEY_ID", ""))
        if not secret and has_jeko_keys and sub.jeko_payment_request_id and not sub.jeko_payment_request_id.startswith("sim_"):
            jeko_data = get_payment_request_status(sub.jeko_payment_request_id)
            verified_status = extract_jeko_status(jeko_data) if jeko_data else ""
            if not is_jeko_status_success(verified_status):
                logger.warning(
                    f"Webhook non signé rejeté : statut Jèko non confirmé pour {sub.reference}."
                )
                return JsonResponse({"error": "Statut non confirmé par Jèko"}, status=401)
        sub.activate_for_30_days()
        logger.info(f"Abonnement {sub.reference} activé pour 30 jours pour {sub.user}.")
    elif is_jeko_status_failed(tx_status):
        sub.status = Subscription.STATUS_CANCELLED
        sub.save(update_fields=["status", "updated_at"])
        logger.info(f"Abonnement {sub.reference} marqué en échec.")

    return JsonResponse({"received": True}, status=200)


def simulate_checkout(request):
    """Portail de simulation de paiement Mobile Money.

    Ne valide JAMAIS un paiement automatiquement : l'utilisateur doit
    explicitement confirmer la transaction avant qu'elle ne soit validée.
    Strictement réservé au mode simulation (JEKO_SIMULATION_MODE, absence de clés Jèko ou ID sim_).
    """
    ref = request.GET.get("ref", "")
    sub = Subscription.objects.filter(reference=ref).first()
    web_app_url = getattr(settings, "WEB_APP_URL", "https://transfert-online.site").rstrip("/")

    if not sub:
        return HttpResponseRedirect(f"{web_app_url}/?payment=error&reason=not_found")

    has_live_jeko_keys = bool(
        getattr(settings, "JEKO_API_KEY", "")
        and getattr(settings, "JEKO_API_KEY_ID", "")
        and getattr(settings, "JEKO_STORE_ID", "")
    )
    is_sim_allowed = (
        getattr(settings, "JEKO_SIMULATION_MODE", False)
        or not has_live_jeko_keys
        or (sub.jeko_payment_request_id and sub.jeko_payment_request_id.startswith("sim_"))
    )
    if not is_sim_allowed:
        logger.warning(f"Tentative d'accès non autorisée à simulate_checkout pour {sub.reference}.")
        return HttpResponseRedirect(f"{web_app_url}/?payment=error&reason=simulation_disabled")

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
    if sub.user.role == User.ROLE_BAILLEUR:
        plan_name = "Bailleur (3 000 FCFA / mois)"
    elif sub.user.role == User.ROLE_AGENT:
        plan_name = "Agent immobilier (3 000 FCFA / mois)"
    else:
        plan_name = "Client (1 000 FCFA / mois)"

    fee_amount = int(round(sub.amount * 0.015))
    total_amount = sub.amount + fee_amount

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
            <div class="amount">{total_amount:,} FCFA</div>
            <div class="details">
                <div class="details-row"><span>Formule :</span><span class="details-val">{plan_name}</span></div>
                <div class="details-row"><span>Frais de transaction (1,5 %) :</span><span class="details-val">{fee_amount:,} FCFA</span></div>
                <div class="details-row"><span>Moyen :</span><span class="details-val">{method_name}</span></div>
                <div class="details-row"><span>Téléphone :</span><span class="details-val">{sub.user.phone}</span></div>
                <div class="details-row"><span>Référence :</span><span class="details-val">{sub.reference}</span></div>
            </div>
            <a href="?ref={ref}&action=confirm" class="btn-confirm">Payer {total_amount:,} FCFA</a>
            <a href="?ref={ref}&action=cancel" class="btn-cancel">Annuler la transaction</a>
        </div>
    </body>
    </html>
    """
    return HttpResponse(html)


def sync_all_recent_pending_subscriptions():
    """Synchronise les abonnements en attente récents (ex: retour Jèko sans paramètre ref)."""
    recent_pending = Subscription.objects.filter(
        status=Subscription.STATUS_PENDING,
    ).order_by("-created_at")[:10]
    activated_sub = None
    for pending in recent_pending:
        if pending.jeko_payment_request_id:
            jeko_data = get_payment_request_status(pending.jeko_payment_request_id)
            if jeko_data:
                tx_status = extract_jeko_status(jeko_data)
                if is_jeko_status_success(tx_status):
                    pending.activate_for_30_days()
                    if not activated_sub:
                        activated_sub = pending
                elif is_jeko_status_failed(tx_status):
                    pending.status = Subscription.STATUS_CANCELLED
                    pending.save(update_fields=["status", "updated_at"])
    return activated_sub


def redirect_success(request):
    """Redirection après paiement validé vers l'application web.
    Vérifie toujours le statut réel auprès de l'API Jèko avant toute activation."""
    web_app_url = getattr(settings, "WEB_APP_URL", "https://transfert-online.site").rstrip("/")
    ref = request.GET.get("ref") or request.GET.get("reference") or request.GET.get("orderId") or ""
    payment_request_id = request.GET.get("id") or request.GET.get("payment_request_id") or ""
    sub = None
    if ref:
        sub = Subscription.objects.filter(reference=ref).first()
    if not sub and payment_request_id:
        sub = Subscription.objects.filter(jeko_payment_request_id=payment_request_id).first()
    if sub:
        if sub.status != Subscription.STATUS_ACTIVE and sub.jeko_payment_request_id:
            jeko_data = get_payment_request_status(sub.jeko_payment_request_id)
            tx_status = extract_jeko_status(jeko_data) if jeko_data else ""
            if is_jeko_status_success(tx_status):
                sub.activate_for_30_days()
            elif is_jeko_status_failed(tx_status):
                sub.status = Subscription.STATUS_CANCELLED
                sub.save(update_fields=["status", "updated_at"])
                return HttpResponseRedirect(f"{web_app_url}/?payment=error&ref={sub.reference}")
        if sub.status == Subscription.STATUS_PENDING:
            return _render_payment_initiated_waiting_page(sub, web_app_url)
        ref = sub.reference
    else:
        activated = sync_all_recent_pending_subscriptions()
        if activated:
            ref = activated.reference
    return HttpResponseRedirect(f"{web_app_url}/?payment=success&ref={ref}")


def redirect_error(request):
    """Redirection en cas d'erreur ou d'annulation vers l'application web."""
    ref = request.GET.get("ref") or request.GET.get("reference") or request.GET.get("orderId") or ""
    if ref:
        sub = Subscription.objects.filter(reference=ref, status=Subscription.STATUS_PENDING).first()
        if sub and sub.jeko_payment_request_id:
            jeko_data = get_payment_request_status(sub.jeko_payment_request_id)
            tx_status = extract_jeko_status(jeko_data) if jeko_data else ""
            if is_jeko_status_failed(tx_status):
                sub.status = Subscription.STATUS_CANCELLED
                sub.save(update_fields=["status", "updated_at"])
    web_app_url = getattr(settings, "WEB_APP_URL", "https://transfert-online.site").rstrip("/")
    return HttpResponseRedirect(f"{web_app_url}/?payment=error&ref={ref}")


def _render_payment_initiated_waiting_page(sub, web_app_url: str) -> HttpResponse:
    """Page officielle affichée juste après la saisie du numéro sur Jèko Mobile Money :
    confirme que le paiement a bien été initié, écoute en temps réel la validation
    finale auprès de Jèko (polling toutes les 2,5 s + bouton manuel) et redirige
    automatiquement vers l'application Web LoueMoi dès que le paiement est finalisé."""
    method_labels = {
        "wave": ("Wave Mobile Money", "#1BA4D9", "#FFFFFF", "Ouvrez votre application Wave ou validez la notification reçue sur votre téléphone."),
        "orange": ("Orange Money", "#FF7900", "#FFFFFF", "Validez le paiement sur votre téléphone (notification Orange Money ou #144#)."),
        "mtn": ("MTN Mobile Money", "#FFCC00", "#0F172A", "Validez la transaction sur votre téléphone (notification MTN MoMo ou *133#)."),
        "moov": ("Moov Money", "#005CA9", "#FFFFFF", "Validez la transaction sur votre téléphone via le menu Moov Money."),
        "djamo": ("Djamo", "#111827", "#FFFFFF", "Confirmez la notification de paiement dans votre application Djamo."),
    }
    method_name, method_color, method_text_color, method_hint = method_labels.get(
        sub.payment_method,
        ("Mobile Money", "#4F46E5", "#FFFFFF", "Validez la demande de paiement sur votre téléphone."),
    )
    if sub.user.role == User.ROLE_BAILLEUR:
        plan_name = "Abonnement Bailleur Certifié"
    elif sub.user.role == User.ROLE_AGENT:
        plan_name = "Abonnement Agent Certifié"
    else:
        plan_name = "Abonnement Client Certifié"

    fee_amount = int(round(sub.amount * 0.015))
    total_amount = sub.amount + fee_amount
    check_url = f"/api/payments/jeko/return/?ref={sub.reference}&check=1"
    success_target = f"{web_app_url}/?payment=success&ref={sub.reference}"
    error_target = f"{web_app_url}/?payment=error&ref={sub.reference}"

    html = f"""<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Paiement Mobile Money initié · LoueMoi × Jèko</title>
    <style>
        * {{ box-sizing: border-box; }}
        body {{
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            display: flex; align-items: center; justify-content: center;
            min-height: 100vh; margin: 0; background: #F1F5F9; padding: 20px; color: #0F172A;
        }}
        .card {{
            background: #FFFFFF; border-radius: 24px; padding: 32px 26px;
            box-shadow: 0 15px 35px rgba(15, 23, 42, 0.08);
            max-width: 440px; width: 100%; text-align: center;
            border-top: 6px solid {method_color};
        }}
        .secure-pill {{
            display: inline-flex; align-items: center; gap: 6px;
            background: #EEF2FF; color: #4338CA; font-size: 12px; font-weight: 700;
            padding: 5px 14px; border-radius: 999px; margin-bottom: 18px;
        }}
        .op-badge {{
            width: 68px; height: 68px; border-radius: 18px;
            background: {method_color}; color: {method_text_color};
            display: flex; align-items: center; justify-content: center;
            font-size: 22px; font-weight: 900; margin: 0 auto 14px;
            box-shadow: 0 8px 20px rgba(0,0,0,0.10);
        }}
        h1 {{ font-size: 21px; font-weight: 800; margin: 0 0 8px; color: #0F172A; }}
        .subtitle {{ font-size: 14px; color: #475569; line-height: 1.45; margin: 0 0 18px; }}
        .status-box {{
            background: #F8FAFC; border: 1px solid #E2E8F0; border-radius: 16px;
            padding: 16px; margin-bottom: 18px; text-align: left;
        }}
        .step {{
            display: flex; align-items: center; gap: 10px;
            font-size: 13.5px; padding: 7px 0; color: #334155; font-weight: 500;
        }}
        .step-done {{ color: #16A34A; font-weight: 700; }}
        .step-active {{ color: #4F46E5; font-weight: 700; }}
        .spinner {{
            width: 18px; height: 18px; border: 2.5px solid #C7D2FE;
            border-top-color: #4F46E5; border-radius: 50%;
            animation: spin 0.9s linear infinite; flex-shrink: 0;
        }}
        @keyframes spin {{ to {{ transform: rotate(360deg); }} }}
        .details {{
            background: #F8FAFC; border-radius: 14px; padding: 12px 16px;
            margin-bottom: 20px; font-size: 13px; text-align: left;
        }}
        .row {{ display: flex; justify-content: space-between; padding: 5px 0; color: #64748B; }}
        .val {{ font-weight: 700; color: #0F172A; }}
        .btn-primary {{
            display: block; width: 100%; background: #4F46E5; color: #FFFFFF;
            border: none; padding: 14px 20px; border-radius: 14px;
            font-weight: 700; font-size: 15px; cursor: pointer;
            text-decoration: none; margin-bottom: 10px; transition: opacity 0.2s;
        }}
        .btn-secondary {{
            display: block; width: 100%; background: #F1F5F9; color: #475569;
            border: none; padding: 12px 18px; border-radius: 12px;
            font-weight: 600; font-size: 13.5px; cursor: pointer; text-decoration: none;
        }}
    </style>
</head>
<body>
    <div class="card">
        <div class="secure-pill">🔒 Passerelle Officielle Jèko × LoueMoi</div>
        <div class="op-badge" id="op-badge">{method_name[:2].upper()}</div>
        <h1 id="main-title">Paiement initié avec succès</h1>
        <p class="subtitle" id="main-subtitle">{method_hint}<br>Cette page détecte automatiquement votre validation et vous redirige vers l'application Web.</p>

        <div class="status-box">
            <div class="step step-done">
                <span>✅</span>
                <span>1. Numéro renseigné &amp; transaction initiée sur Jèko</span>
            </div>
            <div class="step step-active" id="step-2">
                <span class="spinner" id="step-2-icon"></span>
                <span id="step-2-text">2. En attente de confirmation Mobile Money...</span>
            </div>
            <div class="step" id="step-3">
                <span id="step-3-icon">⏳</span>
                <span id="step-3-text">3. Activation du badge &amp; redirection vers l'application Web</span>
            </div>
        </div>

        <div class="details">
            <div class="row"><span>Offre :</span><span class="val">{plan_name}</span></div>
            <div class="row"><span>Opérateur :</span><span class="val">{method_name}</span></div>
            <div class="row"><span>Montant (frais 1,5 % inclus) :</span><span class="val">{total_amount:,} FCFA</span></div>
            <div class="row"><span>Référence :</span><span class="val">{sub.reference}</span></div>
        </div>

        <button type="button" class="btn-primary" id="btn-check" onclick="checkNow()">
            J'ai validé le paiement sur mon téléphone
        </button>
        <a href="{success_target}" class="btn-secondary">
            Aller directement sur l'application Web LoueMoi
        </a>
    </div>

    <script>
        const checkUrl = "{check_url}";
        const successTarget = "{success_target}";
        const errorTarget = "{error_target}";
        let redirecting = false;

        async function pollStatus() {{
            if (redirecting) return;
            try {{
                const resp = await fetch(checkUrl, {{ headers: {{ "Accept": "application/json" }}, cache: "no-store" }});
                if (!resp.ok) return;
                const data = await resp.json();
                if (data.status === "active") {{
                    redirecting = true;
                    document.getElementById("main-title").textContent = "Paiement finalisé & Badge activé !";
                    document.getElementById("main-subtitle").textContent = "Redirection automatique vers l'application Web LoueMoi...";
                    document.getElementById("step-2").className = "step step-done";
                    document.getElementById("step-2-icon").className = "";
                    document.getElementById("step-2-icon").textContent = "✅";
                    document.getElementById("step-2-text").textContent = "2. Paiement Mobile Money confirmé";
                    document.getElementById("step-3").className = "step step-done";
                    document.getElementById("step-3-icon").textContent = "🚀";
                    document.getElementById("step-3-text").textContent = "3. Redirection vers LoueMoi Web...";
                    setTimeout(() => {{ window.location.href = data.redirect_url || successTarget; }}, 900);
                }} else if (data.status === "failed") {{
                    redirecting = true;
                    document.getElementById("main-title").textContent = "Paiement non abouti ou annulé";
                    document.getElementById("main-subtitle").textContent = "La transaction Mobile Money n'a pas été validée.";
                    setTimeout(() => {{ window.location.href = data.redirect_url || errorTarget; }}, 1500);
                }}
            }} catch (e) {{}}
        }}

        function checkNow() {{
            const btn = document.getElementById("btn-check");
            btn.textContent = "Vérification auprès de Jèko en cours...";
            pollStatus().finally(() => {{
                if (!redirecting) {{
                    setTimeout(() => {{ btn.textContent = "J'ai validé le paiement sur mon téléphone"; }}, 1500);
                }}
            }});
        }}

        setInterval(pollStatus, 2500);
        setTimeout(pollStatus, 800);
    </script>
</body>
</html>"""
    return HttpResponse(html)


def jeko_return(request):
    """GET /api/payments/jeko/return/

    Point de retour officiel après la saisie du numéro sur Jèko Checkout :
    - Si le paiement est déjà confirmé par Jèko : active l'abonnement + badge et redirige vers l'application Web.
    - Si le paiement vient d'être initié (Mobile Money en attente de validation sur le téléphone) :
      affiche la page officielle "Paiement initié" qui vérifie en temps réel la finalisation
      et redirige automatiquement l'utilisateur vers l'application Web dès que le paiement est finalisé.
    """
    web_app_url = getattr(settings, "WEB_APP_URL", "https://transfert-online.site").rstrip("/")
    ref = request.GET.get("ref") or request.GET.get("reference") or request.GET.get("orderId") or ""
    payment_request_id = request.GET.get("id") or request.GET.get("payment_request_id") or ""
    is_ajax_check = request.GET.get("check") == "1"
    result_param = (
        request.GET.get("result")
        or request.GET.get("payment")
        or request.GET.get("status")
        or ""
    ).strip().lower()

    sub = None
    if ref:
        sub = Subscription.objects.filter(reference=ref).first()
    if not sub and payment_request_id:
        sub = Subscription.objects.filter(jeko_payment_request_id=payment_request_id).first()

    if sub:
        if sub.status == Subscription.STATUS_ACTIVE:
            target = f"{web_app_url}/?payment=success&ref={sub.reference}"
            if is_ajax_check:
                return JsonResponse({"status": "active", "redirect_url": target})
            return HttpResponseRedirect(target)

        tx_status = ""
        if sub.jeko_payment_request_id:
            jeko_data = get_payment_request_status(sub.jeko_payment_request_id)
            if jeko_data:
                tx_status = extract_jeko_status(jeko_data)

        if is_jeko_status_failed(tx_status):
            sub.status = Subscription.STATUS_CANCELLED
            sub.save(update_fields=["status", "updated_at"])
            target = f"{web_app_url}/?payment=error&ref={sub.reference}"
            if is_ajax_check:
                return JsonResponse({"status": "failed", "redirect_url": target})
            return HttpResponseRedirect(target)

        if is_jeko_status_success(tx_status):
            sub.activate_for_30_days()
            logger.info(
                f"Abonnement {sub.reference} et badge activés après vérification API Jèko pour {sub.user}."
            )
            target = f"{web_app_url}/?payment=success&ref={sub.reference}"
            if is_ajax_check:
                return JsonResponse({"status": "active", "redirect_url": target})
            return HttpResponseRedirect(target)

        if result_param in ("error", "failed", "cancelled", "canceled") and not is_ajax_check:
            return HttpResponseRedirect(f"{web_app_url}/?payment=error&ref={sub.reference}")

        if is_ajax_check:
            return JsonResponse({"status": "pending", "reference": sub.reference})

        # Paiement Mobile Money initié après saisie du numéro sur Jèko :
        # afficher la page officielle d'attente qui redirige automatiquement vers l'app Web une fois finalisé
        return _render_payment_initiated_waiting_page(sub, web_app_url)
    else:
        activated = sync_all_recent_pending_subscriptions()
        if activated:
            target = f"{web_app_url}/?payment=success&ref={activated.reference}"
            if is_ajax_check:
                return JsonResponse({"status": "active", "redirect_url": target})
            return HttpResponseRedirect(target)

    if is_ajax_check:
        return JsonResponse({"status": "pending", "reference": ref})

    if result_param in ("error", "failed", "cancelled", "canceled"):
        return HttpResponseRedirect(f"{web_app_url}/?payment=error&ref={ref}")

    return HttpResponseRedirect(f"{web_app_url}/?payment=pending&ref={ref}")


