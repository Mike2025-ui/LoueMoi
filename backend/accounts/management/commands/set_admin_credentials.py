import re
from django.core.management.base import BaseCommand
from accounts.models import User
from accounts.sms import normalize_phone_number


class Command(BaseCommand):
    help = "Définit ou réinitialise le compte administrateur LoueMoi unique (téléphone et mot de passe)."

    def add_arguments(self, parser):
        parser.add_argument("--phone", type=str, required=True, help="Numéro de téléphone de l'administrateur")
        parser.add_argument("--password", type=str, required=True, help="Nouveau mot de passe administrateur")
        parser.add_argument("--first-name", type=str, default="Super", help="Prénom")
        parser.add_argument("--last-name", type=str, default="Admin", help="Nom")

    def handle(self, *args, **options):
        raw_phone = options["phone"].strip()
        password = options["password"].strip()
        first_name = options["first_name"].strip()
        last_name = options["last_name"].strip()

        clean_raw = re.sub(r"[^\d+]", "", raw_phone)
        normalized = normalize_phone_number(clean_raw or raw_phone)
        candidates = {p for p in (raw_phone, clean_raw, normalized) if p}

        user = User.objects.filter(phone__in=candidates).first()
        if user is None and len(clean_raw) >= 8:
            user = User.objects.filter(phone__endswith=clean_raw[-8:]).first()

        target_phone = normalized if normalized else raw_phone

        if not user:
            user = User.objects.create_superuser(
                phone=target_phone,
                password=password,
                first_name=first_name,
                last_name=last_name,
                role=User.ROLE_ADMIN,
            )
            self.stdout.write(self.style.SUCCESS(f"Superutilisateur créé avec succès : {user.phone}"))
        else:
            user.is_staff = True
            user.is_superuser = True
            user.role = User.ROLE_ADMIN
            user.is_active = True
            user.first_name = first_name
            user.last_name = last_name
            user.set_password(password)
            user.save()
            self.stdout.write(self.style.SUCCESS(f"Superutilisateur {user.phone} mis à jour avec succès avec le nouveau mot de passe."))
