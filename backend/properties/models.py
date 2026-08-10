from django.conf import settings
from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models


class Property(models.Model):
    """Correspond au modèle Property de l'app Flutter (lib/features/properties/models/property.dart)."""

    TYPE_CHOICES = [
        ("logement", "Logement"),
        ("terrain", "Terrain"),
        ("magasin", "Magasin"),
    ]
    TRANSACTION_CHOICES = [
        ("location", "Location"),
        ("vente", "Vente"),
    ]
    STATUS_CHOICES = [
        ("disponible", "Disponible"),
        ("occupee", "Occupée"),
        # Statut admin-only : jamais choisi par l'agent, jamais retourné par
        # /api/properties/ ni /api/agent/properties/ (annonce masquée après
        # intervention de la modération, cf. PropertyViewSet.get_queryset).
        # Aucune étape d'approbation avant publication : une annonce créée
        # par un agent est "disponible" (donc publique) immédiatement.
        ("disabled", "Désactivée (admin)"),
    ]

    title = models.CharField(max_length=200)
    description = models.TextField(blank=True)
    type = models.CharField(max_length=20, choices=TYPE_CHOICES, default="logement")
    category = models.CharField(max_length=100)
    transaction_type = models.CharField(max_length=20, choices=TRANSACTION_CHOICES)

    price = models.DecimalField(max_digits=12, decimal_places=2)
    deposit = models.DecimalField(max_digits=12, decimal_places=2, null=True, blank=True)
    advance = models.DecimalField(max_digits=12, decimal_places=2, null=True, blank=True)

    city = models.CharField(max_length=100, blank=True)
    commune = models.CharField(max_length=100)
    district = models.CharField(max_length=100)
    address = models.CharField(max_length=255, blank=True)
    # Source de vérité géographique : simples DecimalField (pas de PointField/
    # PostGIS — l'environnement de dev tourne sur SQLite sans GDAL/GEOS, voir
    # l'audit de la phase géolocalisation). null=True/blank=True : les
    # annonces existantes ou créées sans position restent valides, juste
    # exclues de la carte et de /api/properties/nearby/.
    latitude = models.DecimalField(
        max_digits=9,
        decimal_places=6,
        null=True,
        blank=True,
        validators=[MinValueValidator(-90), MaxValueValidator(90)],
    )
    longitude = models.DecimalField(
        max_digits=9,
        decimal_places=6,
        null=True,
        blank=True,
        validators=[MinValueValidator(-180), MaxValueValidator(180)],
    )

    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default="disponible")
    is_future = models.BooleanField(default=False)

    images = models.JSONField(default=list, blank=True)
    cover_image = models.CharField(max_length=500, blank=True)
    features = models.JSONField(default=list, blank=True)
    amenities = models.JSONField(default=list, blank=True)

    # Compteurs dénormalisés, incrémentés uniquement côté serveur (jamais
    # par le client) : views_count via l'action `view`, favorites_count
    # tenu à jour par PropertyViewSet.favorite().
    views_count = models.PositiveIntegerField(default=0)
    favorites_count = models.PositiveIntegerField(default=0)

    agent = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name="properties",
        limit_choices_to={"role": "agent"},
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at"]
        verbose_name_plural = "properties"

    def __str__(self):
        return f"{self.title} ({self.commune}, {self.district})"


class Favorite(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="favorites"
    )
    property = models.ForeignKey(
        Property, on_delete=models.CASCADE, related_name="favorited_by"
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ("user", "property")
