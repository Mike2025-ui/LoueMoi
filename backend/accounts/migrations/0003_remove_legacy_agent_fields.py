from django.db import migrations


class Migration(migrations.Migration):
    """Supprime is_agent/is_verified/rating de User une fois leurs données
    copiées vers AgentProfile (agents.0002_backfill_agent_profiles) — plus
    aucune deuxième source de vérité pour le rôle ou le statut vérifié."""

    dependencies = [
        ("accounts", "0002_user_role"),
        ("agents", "0002_backfill_agent_profiles"),
    ]

    operations = [
        migrations.RemoveField(model_name="user", name="is_agent"),
        migrations.RemoveField(model_name="user", name="is_verified"),
        migrations.RemoveField(model_name="user", name="rating"),
    ]
