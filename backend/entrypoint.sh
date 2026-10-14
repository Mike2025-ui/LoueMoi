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

# Création automatique du superutilisateur si configuré
if [ -n "$DJANGO_SUPERUSER_PHONE" ] && [ -n "$DJANGO_SUPERUSER_PASSWORD" ]; then
    echo "Vérification / Création du superutilisateur..."
    python manage.py shell <<END
import os
from accounts.models import User

phone = os.environ.get("DJANGO_SUPERUSER_PHONE")
password = os.environ.get("DJANGO_SUPERUSER_PASSWORD")
first_name = os.environ.get("DJANGO_SUPERUSER_FIRST_NAME", "Admin")
last_name = os.environ.get("DJANGO_SUPERUSER_LAST_NAME", "LoueMoi")

if phone and password:
    if not User.objects.filter(phone=phone).exists():
        User.objects.create_superuser(
            phone=phone,
            password=password,
            first_name=first_name,
            last_name=last_name,
            role=User.ROLE_ADMIN
        )
        print(f"Superutilisateur {phone} créé avec succès.")
    else:
        print(f"Superutilisateur {phone} existe déjà.")
END
fi

# Chargement optionnel des données de démonstration
if [ "$SEED_DEMO_DATA" = "true" ] || [ "$SEED_DEMO_DATA" = "True" ] || [ "$SEED_DEMO_DATA" = "1" ]; then
    echo "Chargement des données de démonstration (seed_demo_data)..."
    python manage.py seed_demo_data || true
fi

echo "Backend LoueMoi prêt. Lancement du serveur d'application..."
exec "$@"

