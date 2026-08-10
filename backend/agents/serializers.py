from rest_framework import serializers

from .models import AgentProfile


class AgentProfileSerializer(serializers.ModelSerializer):
    """`is_verified`/`rating` en lecture seule : jamais modifiables par
    l'agent lui-même, uniquement par l'administration (Django Admin)."""

    class Meta:
        model = AgentProfile
        fields = ["agency_name", "whatsapp", "description", "is_verified", "rating"]
        read_only_fields = ["is_verified", "rating"]
