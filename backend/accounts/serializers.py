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
            "is_staff",
            "is_superuser",
            "activation_requested",
            "activation_requested_at",
            "agent_profile",
            "is_verified",
            "has_active_subscription",
            "is_online",
            "last_seen",
        ]
        # Sécurité stricte : phone, role, is_verified, is_staff, etc. ne sont jamais modifiables via l'API
        read_only_fields = [
            "id",
            "phone",
            "role",
            "is_approved",
            "is_staff",
            "is_superuser",
            "is_verified",
            "activation_requested",
            "activation_requested_at",
            "has_active_subscription",
            "is_online",
            "last_seen",
        ]

    def validate_whatsapp(self, value):
        if not value:
            return ""
        from accounts.sms import normalize_phone_number
        normalized = normalize_phone_number(value)
        return normalized or value.strip()

    def get_is_verified(self, user):
        return bool(getattr(user, "is_verified", False) or user.is_staff or user.is_superuser)

    def update(self, instance, validated_data):
        # Défense en profondeur : rôle et numéro de téléphone strictement immuables
        validated_data.pop("role", None)
        validated_data.pop("phone", None)
        validated_data.pop("is_verified", None)
        return super().update(instance, validated_data)


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=6)
    password_confirm = serializers.CharField(write_only=True, min_length=6)
    role = serializers.ChoiceField(
        choices=[
            (User.ROLE_CLIENT, "Client"),
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
        return attrs

    def create(self, validated_data):
        password = validated_data.pop("password")
        if not validated_data.get("whatsapp"):
            validated_data["whatsapp"] = validated_data.get("phone", "")
        # Toute inscription publique est un compte client actif immédiat
        validated_data["role"] = User.ROLE_CLIENT
        user = User(**validated_data)
        user.set_password(password)
        user.is_approved = True
        user.save()
        return user


class CustomTokenObtainPairSerializer(TokenObtainPairSerializer):
    """Authentifie par téléphone + mot de passe (au lieu de username)."""

    username_field = User.USERNAME_FIELD
