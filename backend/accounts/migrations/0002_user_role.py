from django.db import migrations, models


def backfill_role_from_is_agent(apps, schema_editor):
    """Tout utilisateur existant avec is_agent=True devient role=agent ; les
    autres restent role=client (valeur par défaut du champ)."""
    User = apps.get_model("accounts", "User")
    User.objects.filter(is_agent=True).update(role="agent")


def noop_reverse(apps, schema_editor):
    pass


class Migration(migrations.Migration):

    dependencies = [
        ("accounts", "0001_initial"),
    ]

    operations = [
        migrations.AddField(
            model_name="user",
            name="role",
            field=models.CharField(
                choices=[
                    ("client", "Client"),
                    ("agent", "Agent immobilier"),
                    ("admin", "Administrateur"),
                ],
                default="client",
                max_length=10,
            ),
        ),
        migrations.RunPython(backfill_role_from_is_agent, noop_reverse),
    ]
