from django.conf import settings
from django.db import models


class AgentProfile(models.Model):
    """Informations professionnelles propres aux utilisateurs `role=agent`.
    Un client n'a jamais de AgentProfile (relation 1-1 optionnelle).

    `is_verified` et `rating` sont en lecture seule côté API — un agent ne
    peut jamais s'auto-déclarer vérifié, seule l'administration (Django
    Admin) peut le faire.

    `certification_status` suit la demande de certification (workflow :
    non demandée → en attente → approuvée/refusée). `is_verified` reste le
    booléen que tout le reste du code lit déjà (AgentSearchSerializer,
    badge "vérifié" Flutter...) — on ne le duplique pas avec un deuxième
    booléen équivalent, mais on ne force pas non plus une dépendance stricte
    en base : le workflow normal (AgentCertificationRequestView côté agent,
    puis AgentProfileAdmin.approve_certification/reject_certification côté
    admin) met toujours les deux à jour ensemble, pour qu'ils ne divergent
    jamais en pratique — sans casser le bascule rapide is_verified déjà
    possible depuis la liste Django Admin (list_editable), qui reste
    disponible pour une vérification manuelle hors workflow.
    """

    CERTIFICATION_NOT_REQUESTED = "non_demandee"
    CERTIFICATION_PENDING = "en_attente"
    CERTIFICATION_APPROVED = "approuvee"
    CERTIFICATION_REJECTED = "refusee"
    CERTIFICATION_STATUS_CHOICES = [
        (CERTIFICATION_NOT_REQUESTED, "Non demandée"),
        (CERTIFICATION_PENDING, "En attente"),
        (CERTIFICATION_APPROVED, "Approuvée"),
        (CERTIFICATION_REJECTED, "Refusée"),
    ]

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
    certification_status = models.CharField(
        max_length=20,
        choices=CERTIFICATION_STATUS_CHOICES,
        default=CERTIFICATION_NOT_REQUESTED,
    )
    rating = models.DecimalField(max_digits=3, decimal_places=2, default=0)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Profil agent de {self.user}"
