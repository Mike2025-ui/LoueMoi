from django.contrib.auth import get_user_model
from rest_framework import serializers
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer

from agents.models import AgentProfile
from agents.serializers import AgentProfileSerializer

User = get_user_model()


class UserSerializer(serializers.ModelSerializer):
    # `agent_profile` est null pour un client — jamais généré pour ce rôle.
    agent_profile = AgentProfileSerializer(read_only=True)

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
        ]
        # `role`, `is_approved`, etc. ne sont pas modifiables par l'utilisateur via PATCH /api/users/me/
        read_only_fields = [
            "id",
            "role",
            "is_approved",
            "activation_requested",
            "activation_requested_at",
        ]


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
