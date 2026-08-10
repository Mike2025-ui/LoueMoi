import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    initial = True

    dependencies = [
        ("accounts", "0002_user_role"),
    ]

    operations = [
        migrations.CreateModel(
            name="AgentProfile",
            fields=[
                (
                    "user",
                    models.OneToOneField(
                        on_delete=django.db.models.deletion.CASCADE,
                        primary_key=True,
                        related_name="agent_profile",
                        serialize=False,
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
                ("agency_name", models.CharField(blank=True, max_length=150)),
                (
                    "whatsapp",
                    models.CharField(
                        blank=True,
                        help_text="Contact professionnel, peut différer du WhatsApp personnel de l'utilisateur.",
                        max_length=20,
                    ),
                ),
                ("description", models.TextField(blank=True)),
                ("is_verified", models.BooleanField(default=False)),
                ("rating", models.DecimalField(decimal_places=2, default=0, max_digits=3)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
            ],
        ),
    ]
