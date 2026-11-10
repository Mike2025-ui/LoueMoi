#!/bin/sh
set -e

echo "=========================================="
echo "Démarrage de l'application LoueMoi Backend"
echo "=========================================="

# Attente de la base de données PostgreSQL si configurée
if [ -n "$POSTGRES_HOST" ]; then
    echo "Attente de la disponibilité de PostgreSQL ($POSTGRES_HOST:${POSTGRES_PORT:-5432})..."
    python - <<END
import socket
import time
import os

host = os.environ.get("POSTGRES_HOST", "db")
port = int(os.environ.get("POSTGRES_PORT", 5432))
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
for attempt in range(30):
    try:
        s.connect((host, port))
        s.close()
        print("PostgreSQL est prêt !")
        break
    except socket.error:
        time.sleep(1)
else:
    print("Avertissement: Impossible de joindre PostgreSQL après 30s. Poursuite...")
END
fi

# Application des migrations
echo "Application des migrations de la base de données..."
python manage.py migrate --noinput

# Collecte des fichiers statiques
echo "Collecte des fichiers statiques..."
python manage.py collectstatic --noinput

# Création / Mise à jour du superutilisateur administrateur unique
if [ -n "$DJANGO_SUPERUSER_PHONE" ] && [ -n "$DJANGO_SUPERUSER_PASSWORD" ]; then
    echo "Vérification / Initialisation de l'administrateur unique..."
    python manage.py shell <<END
import os
from accounts.models import User

phone = os.environ.get("DJANGO_SUPERUSER_PHONE", "").strip()
password = os.environ.get("DJANGO_SUPERUSER_PASSWORD", "").strip()
first_name = os.environ.get("DJANGO_SUPERUSER_FIRST_NAME", "Admin").strip()
last_name = os.environ.get("DJANGO_SUPERUSER_LAST_NAME", "LoueMoi").strip()

if phone and password:
    user = User.objects.filter(phone=phone).first()
    if not user:
        User.objects.create_superuser(
            phone=phone,
            password=password,
            first_name=first_name,
            last_name=last_name,
            role=User.ROLE_ADMIN,
        )
        print(f"Administrateur unique ({phone}) créé avec succès.")
    else:
        user.is_staff = True
        user.is_superuser = True
        user.role = User.ROLE_ADMIN
        user.first_name = first_name
        user.last_name = last_name
        user.set_password(password)
        user.save()
        print(f"Administrateur unique ({phone}) mis à jour avec succès.")

    # Nettoyage automatique des anciens comptes de démonstration
    User.objects.filter(phone__in=["+2250700000000", "+2250712345678"]).exclude(phone=phone).delete()
END
fi

# Chargement optionnel des données de démonstration
if [ "$SEED_DEMO_DATA" = "true" ] || [ "$SEED_DEMO_DATA" = "True" ] || [ "$SEED_DEMO_DATA" = "1" ]; then
    echo "Chargement des données de démonstration (seed_demo_data)..."
    python manage.py seed_demo_data || true
fi

# Permissions sur les fichiers statiques et médias pour Nginx (UID 101)
mkdir -p /app/staticfiles /app/media/avatars /app/media/properties
chmod -R 755 /app/media /app/staticfiles 2>/dev/null || true

echo "Backend LoueMoi prêt. Lancement du serveur d'application..."
exec "$@"

