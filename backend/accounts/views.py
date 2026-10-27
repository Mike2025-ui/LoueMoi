from datetime import timedelta
import logging
import os
import uuid
from PIL import Image

logger = logging.getLogger(__name__)

from django.contrib.auth import get_user_model
from django.core.files.storage import default_storage
from django.utils import timezone
from rest_framework import generics, permissions, status
from rest_framework.throttling import ScopedRateThrottle
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.tokens import RefreshToken

from .models import PasswordResetOTP
from .serializers import RegisterSerializer, UserSerializer
from .sms import get_sms_provider

User = get_user_model()


def _auth_payload(user):
    """Construit la réponse attendue par User.fromJson côté Flutter
    (id, first_name, last_name, phone, whatsapp, photo, token)."""
    refresh = RefreshToken.for_user(user)
    data = UserSerializer(user).data
    data["token"] = str(refresh.access_token)
    data["refresh"] = str(refresh)
    return data


class RegisterView(generics.CreateAPIView):
    serializer_class = RegisterSerializer
    permission_classes = [permissions.AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "auth"

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        return Response(_auth_payload(user), status=status.HTTP_201_CREATED)


class LoginView(APIView):
    permission_classes = [permissions.AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "auth"

    def post(self, request):
        phone = request.data.get("phone", "")
        password = request.data.get("password")
        from .sms import normalize_phone_number
        normalized = normalize_phone_number(phone)
        user = User.objects.filter(phone=normalized).first() or User.objects.filter(phone=phone).first()
        if user is None or not user.check_password(password):
            return Response(
                {"detail": "Numéro de téléphone ou mot de passe invalide."},
                status=status.HTTP_401_UNAUTHORIZED,
            )
        # Sans ce contrôle explicite, un compte désactivé (is_active=False,
        # voir DeactivateAccountView) obtenait quand même un token ici — un
        # token qui échouait ensuite sur le tout premier appel authentifié
        # (JWTAuthentication revérifie is_active à chaque requête), mais
        # avec un message d'erreur générique et confus plutôt qu'un refus
        # clair dès la connexion.
        if not user.is_active:
            return Response(
                {"detail": "Ce compte a été désactivé."},
                status=status.HTTP_403_FORBIDDEN,
            )
        try:
            from payments.views import sync_user_pending_subscriptions
            sync_user_pending_subscriptions(user)
        except Exception:
            pass
        return Response(_auth_payload(user))


class LogoutView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        refresh_token = request.data.get("refresh")
        if refresh_token:
            try:
                RefreshToken(refresh_token).blacklist()
            except Exception:
                pass
        return Response(status=status.HTTP_205_RESET_CONTENT)


class MeView(generics.RetrieveUpdateAPIView):
    serializer_class = UserSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_object(self):
        user = self.request.user
        try:
            from payments.views import sync_user_pending_subscriptions
            sync_user_pending_subscriptions(user)
        except Exception:
            pass
        return user


class UserPhotoView(APIView):
    """POST /api/users/me/photo/ — Upload ou mise à jour de la photo de profil (multipart: photo ou image).
    DELETE /api/users/me/photo/ — Suppression de la photo de profil."""

    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        user = request.user
        photo_file = request.FILES.get("photo") or request.FILES.get("image")
        if not photo_file:
            return Response(
                {"photo": ["Aucun fichier reçu."]}, status=status.HTTP_400_BAD_REQUEST
            )

        # Taille maximale 10 Mo
        max_size_bytes = 10 * 1024 * 1024
        if photo_file.size > max_size_bytes:
            return Response(
                {"photo": ["La photo dépasse la taille maximale autorisée (10 Mo)."]},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Validation de l'extension
        ext = os.path.splitext(photo_file.name or "")[1].lower()
        allowed_extensions = {".jpg", ".jpeg", ".png", ".webp"}
        if ext not in allowed_extensions:
            return Response(
                {"photo": ["Format d'image non autorisé (JPG, PNG, WebP uniquement)."]},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Sécurité & Optimisation : vérification d'intégrité et redimensionnement avatar (max 500px, JPEG 85%)
        import io
        from django.core.files.base import ContentFile

        try:
            img = Image.open(photo_file)
            img.verify()
            photo_file.seek(0)

            img = Image.open(photo_file)
            if img.mode in ("RGBA", "P"):
                img = img.convert("RGB")
            max_dim = 500
            if img.width > max_dim or img.height > max_dim:
                img.thumbnail((max_dim, max_dim), Image.Resampling.LANCZOS)

            out_io = io.BytesIO()
            img.save(out_io, format="JPEG", quality=85, optimize=True)
            photo_to_save = ContentFile(out_io.getvalue())
            ext = ".jpg"
        except Exception:
            return Response(
                {"photo": ["Fichier image corrompu ou invalide."]},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Nettoyage de l'ancien fichier d'avatar s'il existe dans le stockage local
        if user.photo and "/media/avatars/" in user.photo:
            try:
                old_relative_path = user.photo.split("/media/", 1)[-1]
                if default_storage.exists(old_relative_path):
                    default_storage.delete(old_relative_path)
            except Exception:
                pass

        safe_file_name = f"avatar_{uuid.uuid4().hex[:12]}{ext}"
        saved_path = default_storage.save(f"avatars/{user.pk}/{safe_file_name}", photo_to_save)
        url = request.build_absolute_uri(default_storage.url(saved_path))

        user.photo = url
        user.save(update_fields=["photo"])
        return Response(UserSerializer(user).data, status=status.HTTP_200_OK)

    def delete(self, request):
        user = request.user
        if user.photo and "/media/avatars/" in user.photo:
            try:
                old_relative_path = user.photo.split("/media/", 1)[-1]
                if default_storage.exists(old_relative_path):
                    default_storage.delete(old_relative_path)
            except Exception:
                pass

        user.photo = None
        user.save(update_fields=["photo"])
        return Response(UserSerializer(user).data, status=status.HTTP_200_OK)


class DeactivateAccountView(APIView):
    """POST /api/users/me/deactivate/ — décision métier retenue :
    désactivation (`is_active=False`), jamais de suppression physique.
    Properties/Reservations/Conversations/Messages/Notifications/Reviews/
    AgentProfile/DeviceToken restent toutes intactes (Property.agent est
    même en PROTECT — un vrai `user.delete()` échouerait de toute façon tant
    que l'utilisateur possède une annonce).

    Exige le mot de passe en confirmation ("authentification
    supplémentaire") : un token JWT valide seul ne suffit pas pour une
    action de cette portée — quelqu'un qui trouve un téléphone déverrouillé
    ne doit pas pouvoir désactiver le compte en un clic.

    Déconnexion immédiate garantie de deux façons complémentaires :
    is_active=False fait échouer JWTAuthentication sur CHAQUE requête
    suivante (vérifié en base à chaque fois, jamais mis en cache dans le
    token — voir CHECK_USER_IS_ACTIVE, activé par défaut), et le refresh
    token de cette session est blacklisté immédiatement si fourni (même
    logique que LogoutView)."""

    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        user = request.user
        password = request.data.get("password")
        if not password or not user.check_password(password):
            return Response(
                {"detail": "Mot de passe incorrect."}, status=status.HTTP_401_UNAUTHORIZED
            )

        user.is_active = False
        user.save(update_fields=["is_active"])

        refresh_token = request.data.get("refresh")
        if refresh_token:
            try:
                RefreshToken(refresh_token).blacklist()
            except Exception:
                pass
        try:
            from rest_framework_simplejwt.token_blacklist.models import OutstandingToken, BlacklistedToken
            for token in OutstandingToken.objects.filter(user=user):
                BlacklistedToken.objects.get_or_create(token=token)
        except Exception:
            pass

        return Response(status=status.HTTP_204_NO_CONTENT)


_GENERIC_OTP_REQUEST_DETAIL = "Si ce numéro est associé à un compte, un code a été envoyé."


class PasswordResetRequestView(APIView):
    """POST /api/auth/password-reset/request/ — {"phone": "..."}

    Étape 1 de "Mot de passe oublié" : Numéro de téléphone → OTP SMS.
    ARCHITECTURE PRÊTE, AUCUN FOURNISSEUR SMS RÉEL BRANCHÉ (voir
    accounts/sms.py) — le code généré et sa validation sont réels, seul
    l'envoi effectif est un bouchon de développement en attendant qu'un
    fournisseur soit choisi.

    Réponse volontairement générique et identique dans tous les cas
    (numéro inexistant, cooldown actif, ou envoi réussi) : ne jamais
    révéler si un numéro de téléphone est associé à un compte
    (énumération de comptes)."""

    permission_classes = [permissions.AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "auth"

    def post(self, request):
        phone = request.data.get("phone", "")
        if not phone:
            return Response({"detail": _GENERIC_OTP_REQUEST_DETAIL})

        from .sms import _mask_phone, normalize_phone_number
        normalized_phone = normalize_phone_number(phone)
        candidate_phones = {p for p in (phone.strip(), normalized_phone) if p}
        if normalized_phone.startswith("+225"):
            candidate_phones.add(normalized_phone[4:])   # e.g. "0701020304"
            candidate_phones.add(normalized_phone[1:])   # e.g. "2250701020304"

        user = User.objects.filter(phone__in=candidate_phones).first()
        if user is None:
            logger.warning(
                "Demande OTP réinitialisation : aucun compte trouvé pour le numéro %s (formats testés: %s)",
                _mask_phone(phone),
                candidate_phones,
            )
            return Response({"detail": _GENERIC_OTP_REQUEST_DETAIL})

        cooldown_start = timezone.now() - timedelta(
            seconds=PasswordResetOTP.REQUEST_COOLDOWN_SECONDS
        )
        recent_request = PasswordResetOTP.objects.filter(
            user=user, created_at__gt=cooldown_start
        ).exists()
        if recent_request:
            logger.warning(
                "Demande OTP pour %s ignorée : cooldown anti-spam actif (%s secondes).",
                _mask_phone(phone),
                PasswordResetOTP.REQUEST_COOLDOWN_SECONDS,
            )
            return Response({"detail": _GENERIC_OTP_REQUEST_DETAIL})

        _otp, code = PasswordResetOTP.generate_for(user)
        target_phone = normalized_phone or user.phone
        logger.info("Envoi d'un nouvel OTP vers %s...", _mask_phone(target_phone))
        get_sms_provider().send(
            target_phone,
            f"Votre code LoueMoi : {code} (valide {PasswordResetOTP.VALIDITY_MINUTES} minutes).",
        )
        return Response({"detail": _GENERIC_OTP_REQUEST_DETAIL})


class PasswordResetConfirmView(APIView):
    """POST /api/auth/password-reset/confirm/ —
    {"phone": "...", "code": "123456", "new_password": "..."}

    Étape 2 : Vérification OTP + Nouveau mot de passe (une seule requête,
    un seul écran côté Flutter) → mot de passe changé, prêt pour la
    connexion. Le code doit correspondre à l'OTP actif le plus récent pour
    ce numéro, non expiré, non déjà utilisé, sous la limite de tentatives —
    sinon "Code invalide ou expiré" générique dans tous les cas (numéro
    inconnu inclus), même logique anti-énumération que la demande."""

    permission_classes = [permissions.AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "auth"

    def post(self, request):
        phone = request.data.get("phone")
        code = request.data.get("code")
        new_password = request.data.get("new_password")

        if not phone or not code or not new_password:
            return Response(
                {"detail": "Numéro, code et nouveau mot de passe requis."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if len(new_password) < 6:
            return Response(
                {"detail": "Le mot de passe doit contenir au moins 6 caractères."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        from .sms import normalize_phone_number
        normalized_phone = normalize_phone_number(phone)
        candidate_phones = {p for p in (phone.strip(), normalized_phone) if p}
        if normalized_phone.startswith("+225"):
            candidate_phones.add(normalized_phone[4:])
            candidate_phones.add(normalized_phone[1:])
        user = User.objects.filter(phone__in=candidate_phones).first()
        otp = (
            PasswordResetOTP.objects.filter(user=user, is_used=False)
            .order_by("-created_at")
            .first()
            if user is not None
            else None
        )
        if otp is None or not otp.check_code(code):
            return Response(
                {"detail": "Code invalide ou expiré."}, status=status.HTTP_400_BAD_REQUEST
            )

        otp.mark_used()
        user.set_password(new_password)
        user.save(update_fields=["password"])
        try:
            from rest_framework_simplejwt.token_blacklist.models import OutstandingToken, BlacklistedToken
            for token in OutstandingToken.objects.filter(user=user):
                BlacklistedToken.objects.get_or_create(token=token)
        except Exception:
            pass
        return Response({"detail": "Mot de passe réinitialisé avec succès."})


class ChangePasswordView(APIView):
    """POST /api/auth/change-password/ — {"current_password": "...", "new_password": "..."}
    Permet à un utilisateur connecté de modifier son mot de passe."""

    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        current_password = request.data.get("current_password", "")
        new_password = request.data.get("new_password", "")

        if not current_password or not new_password:
            return Response(
                {"detail": "Le mot de passe actuel et le nouveau mot de passe sont requis."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        user = request.user
        if not user.check_password(current_password):
            return Response(
                {"detail": "Mot de passe actuel incorrect."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if len(new_password) < 6:
            return Response(
                {"detail": "Le nouveau mot de passe doit contenir au moins 6 caractères."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        user.set_password(new_password)
        user.save(update_fields=["password"])

        try:
            from rest_framework_simplejwt.token_blacklist.models import OutstandingToken, BlacklistedToken
            for token in OutstandingToken.objects.filter(user=user):
                BlacklistedToken.objects.get_or_create(token=token)
        except Exception:
            pass

        return Response({"detail": "Mot de passe modifié avec succès."})


class RequestActivationView(APIView):
    """POST /api/auth/request-activation/
    Permet à un bailleur ou un agent de soumettre une demande d'activation
    à l'administrateur depuis l'application mobile.
    """

    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        user = request.user
        if user.role not in (User.ROLE_AGENT, User.ROLE_BAILLEUR):
            return Response(
                {"detail": "Seuls les agents et bailleurs nécessitent une activation."},
                status=status.HTTP_400_BAD_REQUEST,
            )
        user.activation_requested = True
        user.activation_requested_at = timezone.now()
        user.save(update_fields=["activation_requested", "activation_requested_at"])
        return Response(_auth_payload(user))


class UserPresenceView(APIView):
    """POST /api/users/presence/ — {"status": "online" | "offline"}
    Permet à l'application mobile de signaler que l'utilisateur est actif dans
    l'application (en ligne avec bouton vert) ou a quitté l'application (bouton gris).
    """

    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        status_value = request.data.get("status", "online")
        user = request.user
        if status_value == "offline":
            user.last_seen = timezone.now() - timedelta(minutes=10)
        else:
            user.last_seen = timezone.now()
        user.save(update_fields=["last_seen"])
        return Response({
            "is_online": user.is_online,
            "last_seen": user.last_seen.isoformat() if user.last_seen else None,
        })
