from django.conf import settings
from django.db import models


class AgentProfile(models.Model):
    """Informations professionnelles propres aux utilisateurs `role=agent`.
    Un client n'a jamais de AgentProfile (relation 1-1 optionnelle).

    `is_verified` et `rating` sont en lecture seule côté API — un agent ne
    peut jamais s'auto-déclarer vérifié, seule l'administration (Django
    Admin) peut le faire.
    """

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="agent_profile",
        primary_key=True,
    )
    agency_name = models.CharField(max_length=150, blank=True)
    whatsapp = models.CharField(
        max_length=20,
        blank=True,
        help_text="Contact professionnel, peut différer du WhatsApp personnel de l'utilisateur.",
    )
    description = models.TextField(blank=True)
    is_verified = models.BooleanField(default=False)
    rating = models.DecimalField(max_digits=3, decimal_places=2, default=0)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Profil agent de {self.user}"
