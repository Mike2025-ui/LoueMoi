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
            "agent_profile",
        ]
        # `role` n'est modifiable ni par le client ni par l'agent via PATCH
        # /api/users/me/ — seule l'administration Django peut changer un rôle.
        read_only_fields = ["id", "role"]


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=6)
    password_confirm = serializers.CharField(write_only=True, min_length=6)
    # ChoiceField restreint strictement les valeurs possibles : "admin" (ou
    # toute autre valeur) est rejeté automatiquement par la validation DRF,
    # impossible de créer un compte admin depuis l'inscription publique.
    role = serializers.ChoiceField(
        choices=[(User.ROLE_CLIENT, "Client"), (User.ROLE_AGENT, "Agent immobilier")],
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
        return attrs

    def create(self, validated_data):
        password = validated_data.pop("password")
        validated_data.setdefault("whatsapp", validated_data.get("phone", ""))
        user = User(**validated_data)
        user.set_password(password)
        user.save()
        if user.role == User.ROLE_AGENT:
            # is_verified reste à False par défaut : seule l'administration
            # peut vérifier un agent, jamais l'inscription elle-même.
            AgentProfile.objects.get_or_create(user=user)
        return user


class CustomTokenObtainPairSerializer(TokenObtainPairSerializer):
    """Authentifie par téléphone + mot de passe (au lieu de username)."""

    username_field = User.USERNAME_FIELD
