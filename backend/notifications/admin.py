from django.contrib import admin

from .models import DeviceToken, Notification


@admin.register(Notification)
class NotificationAdmin(admin.ModelAdmin):
    list_display = ["recipient", "type", "title", "is_read", "created_at"]
    list_filter = ["type", "is_read", "created_at"]
    search_fields = ["recipient__phone", "recipient__first_name", "recipient__last_name", "title", "body"]
    readonly_fields = [
        "recipient", "title", "body", "type", "data", "property", "reservation",
        "conversation", "created_at",
    ]


@admin.register(DeviceToken)
class DeviceTokenAdmin(admin.ModelAdmin):
    # `token` n'apparaît jamais tel quel ci-dessous — ni dans list_display,
    # ni dans fields — remplacé partout par masked_token(), une méthode en
    # lecture seule qui ne touche jamais la colonne réelle en base. Avant ce
    # correctif, l'absence de `fields` explicite laissait Django construire
    # le formulaire par défaut à partir de tous les champs modifiables du
    # modèle, donc `token` (CharField brut) s'affichait intégralement et
    # restait éditable dès qu'on ouvrait une fiche.
    list_display = ["user", "platform", "is_active", "masked_token", "created_at", "updated_at"]
    list_filter = ["platform", "is_active"]
    # La recherche reste possible sur le token exact (l'admin doit déjà le
    # connaître pour le taper) : ça ne l'affiche nulle part, contrairement à
    # list_display/fields.
    search_fields = ["user__phone", "user__first_name", "user__last_name", "token"]
    readonly_fields = ["masked_token"]
    fields = ["user", "masked_token", "platform", "is_active"]

    @admin.display(description="Token")
    def masked_token(self, obj):
        # Même convention de troncature que dashboard/templates/dashboard/
        # fcm_list.html (10 premiers caractères + "…" + 4 derniers) — un seul
        # format de token tronqué dans toute l'admin, pas deux différents.
        token = obj.token
        if not token:
            return "—"
        if len(token) <= 14:
            return "•" * len(token)
        return f"{token[:10]}…{token[-4:]}"
