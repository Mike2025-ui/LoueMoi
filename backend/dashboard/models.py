from django.db import models


class AppConfiguration(models.Model):
    """Configuration dynamique de l'application LoueMoi (Solution 2 : Server-Driven Config).
    Pilotée en temps réel depuis le BackOffice sans nécessiter de mise à jour Play Store / APK."""

    singleton_id = models.PositiveSmallIntegerField(default=1, unique=True, editable=False)
    app_version = models.CharField(max_length=20, default="1.0.0+1")
    min_supported_version = models.CharField(max_length=20, default="1.0.0")
    ota_auto_update_enabled = models.BooleanField(
        default=True,
        help_text="Active le téléchargement silencieux des mises à jour OTA (Shorebird) en arrière-plan.",
    )
    maintenance_mode = models.BooleanField(
        default=False,
        help_text="Si activé, affiche un écran de maintenance temporaire dans l'application.",
    )
    maintenance_message = models.TextField(
        default="LoueMoi est actuellement en cours d'optimisation. De retour dans quelques minutes !",
        blank=True,
    )
    announcement_enabled = models.BooleanField(
        default=False,
        help_text="Affiche une bannière d'information dynamique en haut de l'application.",
    )
    announcement_title = models.CharField(max_length=120, blank=True, default="")
    announcement_body = models.TextField(blank=True, default="")
    client_subscription_price = models.PositiveIntegerField(
        default=1000,
        help_text="Tarif mensuel Client en FCFA.",
    )
    pro_subscription_price = models.PositiveIntegerField(
        default=3000,
        help_text="Tarif mensuel Bailleur / Agent en FCFA.",
    )
    enabled_payment_methods = models.CharField(
        max_length=120,
        default="wave,orange,mtn,moov",
        help_text="Liste des opérateurs Mobile Money actifs séparés par une virgule.",
    )
    support_whatsapp = models.CharField(max_length=30, default="+2250700000000", blank=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        verbose_name = "Configuration Dynamique de l'Application"
        verbose_name_plural = "Configuration Dynamique de l'Application"

    def __str__(self):
        return f"Configuration LoueMoi (v{self.app_version})"

    @classmethod
    def get_solo(cls):
        obj, _ = cls.objects.get_or_create(singleton_id=1)
        return obj
