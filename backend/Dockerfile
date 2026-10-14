FROM python:3.12-slim

# Variables d'environnement Python
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    DEBIAN_FRONTEND=noninteractive

# Répertoire de travail
WORKDIR /app

# Installation des dépendances système nécessaires
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libpq-dev \
    libjpeg-dev \
    zlib1g-dev \
    curl \
    dos2unix \
    && rm -rf /var/lib/apt/lists/*

# Installation des dépendances Python
COPY requirements.txt /app/
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copie du code source du backend
COPY . /app/

# Conversion des sauts de ligne pour éviter l'erreur Windows CRLF et attribution des droits
RUN dos2unix /app/entrypoint.sh && \
    chmod +x /app/entrypoint.sh

# Création des dossiers statiques et médias
RUN mkdir -p /app/staticfiles /app/media

# Exposition du port Gunicorn
EXPOSE 8000

# Script d'initialisation et commande par défaut
ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["gunicorn", "config.wsgi:application", "--bind", "0.0.0.0:8000", "--workers", "3", "--threads", "2", "--timeout", "120", "--access-logfile", "-", "--error-logfile", "-"]

