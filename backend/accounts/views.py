from datetime import timedelta

from django.contrib.auth import get_user_model
from django.utils import timezone
from rest_framework import generics, permissions, status
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

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        return Response(_auth_payload(user), status=status.HTTP_201_CREATED)


class LoginView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        phone = request.data.get("phone")
        password = request.data.get("password")
        user = User.objects.filter(phone=phone).first()
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
        return self.request.user


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

    def post(self, request):
        phone = request.data.get("phone")
        if not phone:
            return Response({"detail": _GENERIC_OTP_REQUEST_DETAIL})

        user = User.objects.filter(phone=phone).first()
        if user is None:
            return Response({"detail": _GENERIC_OTP_REQUEST_DETAIL})

        cooldown_start = timezone.now() - timedelta(
            seconds=PasswordResetOTP.REQUEST_COOLDOWN_SECONDS
        )
        recent_request = PasswordResetOTP.objects.filter(
            user=user, created_at__gt=cooldown_start
        ).exists()
        if recent_request:
            # Cooldown actif : ni nouveau code, ni indice donné à l'appelant
            # (même réponse générique) — évite le spam de SMS.
            return Response({"detail": _GENERIC_OTP_REQUEST_DETAIL})

        _otp, code = PasswordResetOTP.generate_for(user)
        get_sms_provider().send(
            phone,
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

        user = User.objects.filter(phone=phone).first()
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
        return Response({"detail": "Mot de passe réinitialisé avec succès."})


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
