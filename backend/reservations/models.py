from django.conf import settings
from django.db import models

from properties.models import Property


class Reservation(models.Model):
    """Correspond à Reservation côté Flutter
    (lib/features/reservations/models/reservation.dart). Les valeurs de
    `status` reprennent exactement les noms de l'enum Dart ReservationStatus
    (enCours, accomplie, annulee) pour un parsing direct côté client."""

    STATUS_CHOICES = [
        ("enCours", "En cours"),
        ("accomplie", "Accomplie"),
        ("annulee", "Annulée"),
    ]

    property = models.ForeignKey(Property, on_delete=models.PROTECT, related_name="reservations")
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="reservations"
    )
    rent = models.DecimalField(max_digits=12, decimal_places=2)
    deposit = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    advance = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default="enCours")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]
        indexes = [
            models.Index(
                fields=["property", "status"],
                name="res_prop_status_idx",
            ),
            models.Index(
                fields=["user", "status"],
                name="res_user_status_idx",
            ),
        ]

    def total(self):
        # Note : le champ FK ci-dessus s'appelle `property`, ce qui masque le
        # builtin `property` dans cette classe — `total` reste donc une
        # méthode normale plutôt qu'une @property.
        return self.rent + self.deposit + self.advance

    def __str__(self):
        return f"{self.user} → {self.property} ({self.status})"
