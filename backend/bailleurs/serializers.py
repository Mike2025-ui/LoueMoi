from rest_framework import serializers


class BailleurSearchSerializer(serializers.Serializer):
    """Utilisé uniquement par GET /api/bailleurs/ (recherche publique, tout
    utilisateur y compris anonyme) — symétrique de AgentSearchSerializer
    (voir agents.serializers). N'expose que des informations publiques
    utiles à un agent pour identifier puis contacter un bailleur, jamais
    mot de passe/tokens/champ interne. Un bailleur n'a pas de profil
    professionnel séparé (pas d'équivalent AgentProfile — agency_name/
    description/rating n'existent pas pour ce rôle) : on n'invente pas ces
    champs ici."""

    id = serializers.IntegerField(source="pk")
    first_name = serializers.CharField()
    last_name = serializers.CharField()
    photo = serializers.CharField(allow_null=True)
    # Numéro public, volontairement exposé : sert directement au bouton
    # "Appeler" (téléphonie native) côté Flutter — même principe que
    # AgentSearchSerializer.phone.
    phone = serializers.CharField()
    is_verified = serializers.SerializerMethodField()

    def get_is_verified(self, user):
        from django.utils import timezone
        now = timezone.now()
        # 1. Tout abonnement actif confère automatiquement le badge vérifié
        if hasattr(user, "subscriptions") and user.subscriptions.filter(status="active", expires_at__gt=now).exists():
            return True
        # 2. Après expiration ou annulation d'un abonnement, le badge est révoqué
        if hasattr(user, "subscriptions") and user.subscriptions.filter(status__in=["active", "expired", "cancelled"]).exists():
            return False
        # 3. Badge administratif
        return bool(getattr(user, "is_verified", False))

