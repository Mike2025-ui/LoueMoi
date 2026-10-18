from datetime import timedelta
from decimal import Decimal

from django.conf import settings
from django.core.validators import MaxValueValidator, MinValueValidator
from django.db import models
from django.utils import timezone


def property_video_path(instance, filename):
    return f"properties/{instance.pk}/video/{filename}"


class Property(models.Model):
    """Correspond au modèle Property de l'app Flutter (lib/features/properties/models/property.dart)."""

    PROPERTY_VALIDITY_DAYS = 30

    # Point 2 — vidéo dans les annonces : décision métier validée (une vidéo
    # facultative au maximum par annonce, MP4, ≤50 Mo, ≤60 s). Voir
    # PropertyViewSet.upload_video et properties/video_utils.py.
    MAX_VIDEO_SIZE_BYTES = 50 * 1024 * 1024
    MAX_VIDEO_DURATION_SECONDS = 60
    ALLOWED_VIDEO_EXTENSIONS = {".mp4"}
    ALLOWED_VIDEO_CONTENT_TYPES = {"video/mp4"}

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
        # "occupee" (location) et "vendue" (vente) sont deux statuts
        # distincts, jamais interchangeables : PropertyViewSet.mark_status
        # n'accepte "occupee" que pour transaction_type="location" et
        # "vendue" que pour transaction_type="vente" — décision métier,
        # voir le commentaire de mark_status.
        ("occupee", "Occupée"),
        ("vendue", "Vendue"),
        ("accomplie", "Accomplie"),
        ("annulee", "Annulée"),
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
        validators=[MinValueValidator(Decimal("-90")), MaxValueValidator(Decimal("90"))],
    )
    longitude = models.DecimalField(
        max_digits=9,
        decimal_places=6,
        null=True,
        blank=True,
        validators=[MinValueValidator(Decimal("-180")), MaxValueValidator(Decimal("180"))],
    )

    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default="disponible")
    is_future = models.BooleanField(default=False)

    images = models.JSONField(default=list, blank=True)
    cover_image = models.CharField(max_length=500, blank=True)
    features = models.JSONField(default=list, blank=True)
    amenities = models.JSONField(default=list, blank=True)

    # Vidéo facultative, une seule par annonce (voir upload_video : un
    # nouvel envoi remplace toujours l'ancienne). FileField (comme
    # Message.attachment côté messagerie — infrastructure de stockage déjà
    # existante réutilisée, pas de deuxième architecture) plutôt qu'une URL
    # en string comme `images` : le suivi du chemin de stockage permet un
    # nettoyage fiable du fichier au remplacement/à la suppression.
    video = models.FileField(upload_to=property_video_path, null=True, blank=True)

    # Compteurs dénormalisés, incrémentés uniquement côté serveur (jamais
    # par le client) : views_count via l'action `view`, favorites_count
    # tenu à jour par PropertyViewSet.favorite().
    views_count = models.PositiveIntegerField(default=0)
    favorites_count = models.PositiveIntegerField(default=0)

    # Nom de colonne conservé pour compatibilité (contrat API/Flutter déjà
    # établi) — accepte aussi bien un agent qu'un bailleur, deux rôles
    # indépendants pouvant tous deux posséder des annonces.
    agent = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name="properties",
        limit_choices_to={"role__in": ["agent", "bailleur"]},
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    # Décision métier retenue : une annonce publiée reste valide 30 jours
    # (PROPERTY_VALIDITY_DAYS), après quoi elle disparaît des résultats
    # publics — PropertyViewSet.get_queryset filtre sur expires_at, jamais
    # recalculé côté Flutter. "Reconduire" (PropertyViewSet.renew) fixe une
    # nouvelle période de 30 jours à partir de maintenant, sans jamais créer
    # de doublon ni toucher aux photos/réservations existantes (même id,
    # même propriétaire). published_at et expires_at sont distincts de
    # created_at/updated_at : created_at ne bouge jamais (date de création
    # réelle de la ligne), published_at est repoussé à chaque reconduction.
    published_at = models.DateTimeField(null=True, blank=True)
    expires_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        # `-id` en second critère : `-created_at` seul n'est pas un ordre
        # total (deux annonces peuvent partager la même seconde de
        # création — cas réel avec plusieurs photos publiées en rafale ou
        # en fixtures/tests). Sans tiebreaker, SQL ne garantit pas un ordre
        # stable entre deux exécutions de la même requête pour les lignes à
        # égalité : la pagination par page (LIMIT/OFFSET, voir
        # /api/properties/) peut alors renvoyer deux fois la même annonce
        # sur deux pages consécutives, ou en sauter une — la cause racine
        # technique la plus plausible d'un "doublon dans la recherche" côté
        # Flutter, qui se contente d'afficher tel quel ce que Django renvoie.
        ordering = ["-created_at", "-id"]
        verbose_name_plural = "properties"

    def __str__(self):
        return f"{self.title} ({self.commune}, {self.district})"

    def publish_for_new_period(self):
        """Fixe une nouvelle période de validité de PROPERTY_VALIDITY_DAYS
        jours à partir de maintenant — utilisé à la fois à la création
        (perform_create) et à la reconduction (renew), pour ne jamais avoir
        deux endroits qui calculent cette date différemment."""
        self.published_at = timezone.now()
        self.expires_at = self.published_at + timedelta(days=self.PROPERTY_VALIDITY_DAYS)

    @property
    def is_expired(self):
        return self.expires_at is not None and self.expires_at < timezone.now()


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
