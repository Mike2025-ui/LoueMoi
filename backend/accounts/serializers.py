from django.contrib.auth import get_user_model
from rest_framework import serializers
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer

from agents.models import AgentProfile
from agents.serializers import AgentProfileSerializer

User = get_user_model()


class UserSerializer(serializers.ModelSerializer):
    # `agent_profile` est null pour un client — jamais généré pour ce rôle.
    agent_profile = AgentProfileSerializer(read_only=True)
    is_verified = serializers.SerializerMethodField()
    has_active_subscription = serializers.BooleanField(read_only=True)
    is_online = serializers.BooleanField(read_only=True)

    class Meta:
        model = User
        fields = [
            "id",
            "first_name",
            "last_name",
            "phone",
            "whatsapp",
            "photo",
            "role",
            "is_approved",
            "activation_requested",
            "activation_requested_at",
            "agent_profile",
            "is_verified",
            "has_active_subscription",
            "is_online",
            "last_seen",
        ]
        # Sécurité stricte : phone, role, is_verified, etc. ne sont jamais modifiables via l'API
        read_only_fields = [
            "id",
            "phone",
            "role",
            "is_approved",
            "is_verified",
            "activation_requested",
            "activation_requested_at",
            "has_active_subscription",
            "is_online",
            "last_seen",
        ]

    def get_is_verified(self, user):
        # Décision souveraine de l'administration : si révoqué ou désactivé, le badge est False
        if not getattr(user, "is_verified", False):
            return False
        from django.utils import timezone
        now = timezone.now()
        # 1. Tout utilisateur avec un abonnement actif bénéficie du badge certifié
        if hasattr(user, "subscriptions") and user.subscriptions.filter(status="active", expires_at__gt=now).exists():
            return True
        # 2. Si l'utilisateur a eu un abonnement qui a expiré ou a été annulé, le badge est révoqué
        if hasattr(user, "subscriptions") and user.subscriptions.filter(status__in=["expired", "cancelled"]).exists():
            return False
        # 3. Badge attribué aux agents ou bailleurs en base ou via leur profil
        if user.role in (User.ROLE_AGENT, User.ROLE_BAILLEUR):
            profile = getattr(user, "agent_profile", None)
            if profile and profile.is_verified:
                return True
            return False
        return False

    def update(self, instance, validated_data):
        # Défense en profondeur : rôle et numéro de téléphone strictement immuables
        validated_data.pop("role", None)
        validated_data.pop("phone", None)
        validated_data.pop("is_verified", None)
        return super().update(instance, validated_data)


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=6)
    password_confirm = serializers.CharField(write_only=True, min_length=6)
    # ChoiceField restreint strictement les valeurs possibles : "admin" (ou
    # toute autre valeur) est rejeté automatiquement par la validation DRF,
    # impossible de créer un compte admin depuis l'inscription publique.
    role = serializers.ChoiceField(
        choices=[
            (User.ROLE_CLIENT, "Client"),
            (User.ROLE_BAILLEUR, "Bailleur"),
            (User.ROLE_AGENT, "Agent immobilier"),
        ],
        default=User.ROLE_CLIENT,
    )

    class Meta:
        model = User
        fields = [
            "first_name",
            "last_name",
            "phone",
            "whatsapp",
            "password",
            "password_confirm",
            "role",
        ]

    def validate_phone(self, value):
        from accounts.sms import normalize_phone_number
        normalized = normalize_phone_number(value)
        if not normalized:
            raise serializers.ValidationError("Numéro de téléphone invalide.")
        if User.objects.filter(phone=normalized).exists():
            raise serializers.ValidationError("Ce numéro de téléphone est déjà associé à un compte.")
        return normalized

    def validate_whatsapp(self, value):
        if not value:
            return ""
        from accounts.sms import normalize_phone_number
        return normalize_phone_number(value)

    def validate(self, attrs):
        if attrs["password"] != attrs.pop("password_confirm"):
            raise serializers.ValidationError(
                {"password_confirm": "Les mots de passe ne correspondent pas."}
            )
        role = attrs.get("role", User.ROLE_CLIENT)
        whatsapp = (attrs.get("whatsapp") or "").strip()
        if role in (User.ROLE_BAILLEUR, User.ROLE_AGENT) and not whatsapp:
            raise serializers.ValidationError(
                {"whatsapp": "Le numéro WhatsApp est requis pour l'activation du compte."}
            )
        return attrs

    def create(self, validated_data):
        password = validated_data.pop("password")
        if not validated_data.get("whatsapp"):
            validated_data["whatsapp"] = validated_data.get("phone", "")
        user = User(**validated_data)
        user.set_password(password)
        # Les comptes agent et bailleur doivent être activés par un administrateur
        if user.role in (User.ROLE_AGENT, User.ROLE_BAILLEUR):
            user.is_approved = False
            user.activation_requested = False
        else:
            user.is_approved = True
        user.save()
        if user.role == User.ROLE_AGENT:
            # is_verified reste à False par défaut : seule l'administration
            # peut vérifier un agent, jamais l'inscription elle-même.
            AgentProfile.objects.get_or_create(user=user)
        return user


class CustomTokenObtainPairSerializer(TokenObtainPairSerializer):
    """Authentifie par téléphone + mot de passe (au lieu de username)."""

    username_field = User.USERNAME_FIELD
