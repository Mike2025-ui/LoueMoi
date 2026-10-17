from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('accounts', '0005_passwordresetotp'),
    ]

    operations = [
        migrations.AddField(
            model_name='user',
            name='is_approved',
            field=models.BooleanField(
                default=True,
                help_text="Les comptes bailleur et agent doivent être activés par l'administrateur.",
            ),
        ),
        migrations.AddField(
            model_name='user',
            name='activation_requested',
            field=models.BooleanField(
                default=False,
                help_text="Indique si l'utilisateur a soumis une demande d'activation.",
            ),
        ),
        migrations.AddField(
            model_name='user',
            name='activation_requested_at',
            field=models.DateTimeField(
                blank=True,
                null=True,
            ),
        ),
    ]

