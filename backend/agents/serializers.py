from rest_framework import serializers

from .models import AgentProfile


class AgentProfileSerializer(serializers.ModelSerializer):
    """`is_verified`/`rating` en lecture seule : jamais modifiables par
    l'agent lui-même, uniquement par l'administration (Django Admin)."""

    class Meta:
        model = AgentProfile
        fields = [
            "agency_name",
            "whatsapp",
            "description",
            "is_verified",
            "certification_status",
            "rating",
        ]
        # certification_status ne se modifie jamais via ce serializer (PATCH
        # /api/agent/profile/) : uniquement via AgentCertificationRequestView
        # (la demande, côté agent) ou Django Admin (l'approbation/le refus,
        # côté admin) — jamais une simple écriture de champ.
        read_only_fields = ["is_verified", "certification_status", "rating"]


class AgentSearchSerializer(serializers.Serializer):
    """Utilisé uniquement par GET /api/agents/ (recherche publique, tout
    utilisateur y compris anonyme). N'expose QUE des informations publiques
    utiles à un bailleur/client pour choisir puis contacter un agent —
    jamais mot de passe, tokens, ou tout champ interne/administratif."""

    id = serializers.IntegerField(source="pk")
    first_name = serializers.CharField()
    last_name = serializers.CharField()
    photo = serializers.CharField(allow_null=True)
    # Numéro public, volontairement exposé : sert directement au bouton
    # "Appeler" (téléphonie native) côté Flutter — c'est la seule raison de
    # publier ce champ, jamais utilisé ailleurs.
    phone = serializers.CharField()
    agency_name = serializers.SerializerMethodField()
    description = serializers.SerializerMethodField()
    rating = serializers.SerializerMethodField()
    is_verified = serializers.SerializerMethodField()

    def _profile(self, user):
        return getattr(user, "agent_profile", None)

    def get_agency_name(self, user):
        profile = self._profile(user)
        return profile.agency_name if profile else ""

    def get_description(self, user):
        profile = self._profile(user)
        return profile.description if profile else ""

    def get_rating(self, user):
        profile = self._profile(user)
        return float(profile.rating) if profile else 0.0

    def get_is_verified(self, user):
        from django.utils import timezone
        now = timezone.now()
        if hasattr(user, "subscriptions") and user.subscriptions.filter(status="active", expires_at__gt=now).exists():
            return True
        if hasattr(user, "subscriptions") and user.subscriptions.filter(status__in=["active", "expired"]).exists():
            return False
        profile = self._profile(user)
        return bool(profile and profile.is_verified)
