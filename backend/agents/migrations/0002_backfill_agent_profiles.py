from django.db import migrations


def backfill_agent_profiles(apps, schema_editor):
    """Crée un AgentProfile pour chaque utilisateur déjà role=agent, en
    reprenant les anciennes valeurs is_verified/rating/whatsapp de User
    avant qu'elles ne soient supprimées (migration accounts suivante)."""
    User = apps.get_model("accounts", "User")
    AgentProfile = apps.get_model("agents", "AgentProfile")
    for user in User.objects.filter(role="agent"):
        AgentProfile.objects.get_or_create(
            user=user,
            defaults={
                "whatsapp": user.whatsapp,
                "is_verified": user.is_verified,
                "rating": user.rating,
            },
        )


def noop_reverse(apps, schema_editor):
    pass


class Migration(migrations.Migration):

    dependencies = [
        ("agents", "0001_initial"),
        ("accounts", "0002_user_role"),
    ]

    operations = [
        migrations.RunPython(backfill_agent_profiles, noop_reverse),
    ]
