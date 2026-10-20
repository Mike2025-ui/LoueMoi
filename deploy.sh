#!/usr/bin/env bash
# ==============================================================================
# Script de Déploiement Haute Puissance — LoueMoi
# Stack : Docker, Docker Compose, Gunicorn, PostgreSQL, Nginx, Certbot SSL
# ==============================================================================

set -eo pipefail

# Couleurs pour l'affichage console
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Répertoire du script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Fonctions d'affichage
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCÈS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[ATTENTION]${NC} $1"; }
log_error() { echo -e "${RED}[ERREUR]${NC} $1" >&2; }
log_title() {
    echo -e "\n${CYAN}${BOLD}====================================================================${NC}"
    echo -e "${CYAN}${BOLD}  $1${NC}"
    echo -e "${CYAN}${BOLD}====================================================================${NC}\n"
}

# Détection de la commande Docker Compose (v2 'docker compose' ou v1 'docker-compose')
detect_docker_compose() {
    if docker compose version >/dev/null 2>&1; then
        DOCKER_COMPOSE="docker compose"
    elif which docker-compose >/dev/null 2>&1; then
        DOCKER_COMPOSE="docker-compose"
    else
        DOCKER_COMPOSE=""
    fi
}

# Installation automatique des dépendances sur Linux
install_prerequisites() {
    log_title "Vérification et installation des prérequis système"
    
    if [ "$EUID" -ne 0 ]; then
        log_warning "Ce script n'est pas exécuté en root. Certaines installations peuvent nécessiter sudo."
        SUDO="sudo"
    else
        SUDO=""
    fi

    # Détection de l'OS
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
    else
        OS="unknown"
    fi

    log_info "Système d'exploitation détecté : $OS"

    # Vérification de Docker
    if ! which docker >/dev/null 2>&1; then
        log_warning "Docker n'est pas installé. Installation automatique en cours..."
        case "$OS" in
            ubuntu|debian)
                $SUDO apt-get update -y
                $SUDO apt-get install -y ca-certificates curl gnupg lsb-release ufw
                $SUDO install -m 0755 -d /etc/apt/keyrings
                curl -fsSL https://download.docker.com/linux/$OS/gpg | $SUDO gpg --dearmor -o /etc/apt/keyrings/docker.gpg --yes
                $SUDO chmod a+r /etc/apt/keyrings/docker.gpg
                echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS $(lsb_release -cs) stable" | $SUDO tee /etc/apt/sources.list.d/docker.list > /dev/null
                $SUDO apt-get update -y
                $SUDO apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
                $SUDO systemctl enable --now docker
                ;;
            centos|rhel|almalinux|rocky)
                $SUDO yum install -y yum-utils
                $SUDO yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
                $SUDO yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
                $SUDO systemctl enable --now docker
                ;;
            *)
                log_error "Distribution $OS non reconnue pour l'installation automatique de Docker. Veuillez installer Docker manuellement."
                exit 1
                ;;
        esac
        log_success "Docker a été installé avec succès."
    else
        log_info "Docker est déjà installé : $(docker --version)"
    fi

    detect_docker_compose
    if [ -z "$DOCKER_COMPOSE" ]; then
        log_error "Docker Compose n'a pas été trouvé. Veuillez installer docker-compose-plugin."
        exit 1
    else
        log_info "Docker Compose détecté : $($DOCKER_COMPOSE version)"
    fi

    # Vérification des outils de base
    for cmd in curl openssl git; do
        if ! which $cmd >/dev/null 2>&1; then
            log_info "Installation de l'outil manquant : $cmd"
            if [ "$OS" = "ubuntu" ] || [ "$OS" = "debian" ]; then
                $SUDO apt-get install -y $cmd
            elif [ "$OS" = "centos" ] || [ "$OS" = "rhel" ] || [ "$OS" = "almalinux" ]; then
                $SUDO yum install -y $cmd
            fi
        fi
    done
}

# Configuration du Pare-feu (UFW)
configure_firewall() {
    if which ufw >/dev/null 2>&1; then
        log_info "Configuration des règles de pare-feu UFW..."
        $SUDO ufw allow 22/tcp comment 'SSH' || true
        $SUDO ufw allow 80/tcp comment 'HTTP Nginx & Certbot' || true
        $SUDO ufw allow 443/tcp comment 'HTTPS Nginx' || true
        $SUDO ufw --force enable || true
        log_success "Ports 22, 80 et 443 ouverts dans le pare-feu."
    fi
}

# Gestion et création du fichier .env
setup_env() {
    log_title "Configuration des Variables d'Environnement (.env)"

    if [ ! -f .env ]; then
        if [ -f .env.example ]; then
            cp .env.example .env
            log_info "Fichier .env initialisé depuis .env.example."
        else
            touch .env
        fi
    fi

    # Source le .env existant
    set -a
    [ -f .env ] && . .env
    set +a

    # Demande interactive des variables indispensables si absentes ou par défaut
    if [ -z "$DOMAIN" ] || [ "$DOMAIN" = "api.votredomaine.com" ]; then
        echo -e "${YELLOW}Quel est le nom de domaine complet pour l'application ? (ex: api.louemoi.ci ou louemoi.com)${NC}"
        read -r -p "Domaine : " INPUT_DOMAIN
        DOMAIN=${INPUT_DOMAIN:-api.louemoi.ci}
    fi

    if [ -z "$SSL_EMAIL" ] || [ "$SSL_EMAIL" = "contact@votredomaine.com" ]; then
        echo -e "${YELLOW}Quelle adresse email utiliser pour les alertes SSL Let's Encrypt ?${NC}"
        read -r -p "Email SSL : " INPUT_EMAIL
        SSL_EMAIL=${INPUT_EMAIL:-admin@$DOMAIN}
    fi

    # Génération automatique d'une clé secrète Django robuste si nécessaire
    if [ -z "$DJANGO_SECRET_KEY" ] || [[ "$DJANGO_SECRET_KEY" == *"change_me"* ]]; then
        DJANGO_SECRET_KEY=$(openssl rand -base64 48 | tr -dc 'a-zA-Z0-9!@#$%^&*(-_=+)' | head -c 50)
        log_info "Nouvelle clé DJANGO_SECRET_KEY sécurisée générée."
    fi

    # Mot de passe Postgres
    if [ -z "$POSTGRES_PASSWORD" ] || [ "$POSTGRES_PASSWORD" = "un_mot_de_passe_tres_securise_ici" ]; then
        POSTGRES_PASSWORD=$(openssl rand -hex 16)
        log_info "Mot de passe PostgreSQL sécurisé généré."
    fi

    POSTGRES_DB=${POSTGRES_DB:-louemoi_db}
    POSTGRES_USER=${POSTGRES_USER:-louemoi_user}
    POSTGRES_HOST=db
    POSTGRES_PORT=5432
    DJANGO_DEBUG=${DJANGO_DEBUG:-False}
    SEED_DEMO_DATA=${SEED_DEMO_DATA:-True}
    GUNICORN_WORKERS=${GUNICORN_WORKERS:-3}
    GUNICORN_THREADS=${GUNICORN_THREADS:-2}

    # Détection de l'IP publique du serveur
    SERVER_IP=$(curl -s --max-time 3 https://api.ipify.org 2>/dev/null || echo "180.149.197.188")

    # Configuration des hôtes et CSRF
    DJANGO_ALLOWED_HOSTS="$DOMAIN,www.$DOMAIN,$SERVER_IP,localhost,127.0.0.1,web"
    DJANGO_CORS_ALLOWED_ORIGINS="https://$DOMAIN,http://$DOMAIN,https://www.$DOMAIN,http://$SERVER_IP"
    DJANGO_CSRF_TRUSTED_ORIGINS="https://$DOMAIN,http://$DOMAIN,https://www.$DOMAIN,http://$SERVER_IP"


    # Superutilisateur
    DJANGO_SUPERUSER_PHONE=${DJANGO_SUPERUSER_PHONE:-"+2250700000000"}
    DJANGO_SUPERUSER_PASSWORD=${DJANGO_SUPERUSER_PASSWORD:-"LoueMoiAdmin2026!"}
    DJANGO_SUPERUSER_FIRST_NAME=${DJANGO_SUPERUSER_FIRST_NAME:-"Admin"}
    DJANGO_SUPERUSER_LAST_NAME=${DJANGO_SUPERUSER_LAST_NAME:-"LoueMoi"}

    # Sauvegarde dans le fichier .env
    cat <<EOF > .env
# Configuration de Production LoueMoi
DOMAIN=$DOMAIN
SSL_EMAIL=$SSL_EMAIL
SSL_STAGING=${SSL_STAGING:-false}

DJANGO_SECRET_KEY=$DJANGO_SECRET_KEY
DJANGO_DEBUG=$DJANGO_DEBUG
DJANGO_ALLOWED_HOSTS=$DJANGO_ALLOWED_HOSTS
DJANGO_CORS_ALLOWED_ORIGINS=$DJANGO_CORS_ALLOWED_ORIGINS
DJANGO_CSRF_TRUSTED_ORIGINS=$DJANGO_CSRF_TRUSTED_ORIGINS

POSTGRES_DB=$POSTGRES_DB
POSTGRES_USER=$POSTGRES_USER
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
POSTGRES_HOST=$POSTGRES_HOST
POSTGRES_PORT=$POSTGRES_PORT

DJANGO_SUPERUSER_PHONE=$DJANGO_SUPERUSER_PHONE
DJANGO_SUPERUSER_PASSWORD=$DJANGO_SUPERUSER_PASSWORD
DJANGO_SUPERUSER_FIRST_NAME=$DJANGO_SUPERUSER_FIRST_NAME
DJANGO_SUPERUSER_LAST_NAME=$DJANGO_SUPERUSER_LAST_NAME

SEED_DEMO_DATA=$SEED_DEMO_DATA
GUNICORN_WORKERS=$GUNICORN_WORKERS
GUNICORN_THREADS=$GUNICORN_THREADS
FIREBASE_CREDENTIALS_JSON=${FIREBASE_CREDENTIALS_JSON:-}
EOF

    log_success "Fichier .env mis à jour avec succès pour le domaine : $DOMAIN"
}

# Libération des ports 80 et 443 sur l'hôte et arrêt de Nginx
free_ports_and_stop_nginx() {
    log_info "Vérification et libération des ports 80 et 443..."
    
    # 1. Arrêter les conteneurs Docker existants qui occupent le port 80/443
    if [ -n "$DOCKER_COMPOSE" ]; then
        log_info "Arrêt temporaire du conteneur Nginx Docker..."
        $DOCKER_COMPOSE stop nginx || true
    fi

    # 2. Vérifier si un serveur Apache ou Nginx tourne sur l'hôte natif
    if which systemctl >/dev/null 2>&1; then
        if systemctl is-active --quiet nginx 2>/dev/null; then
            log_warning "Un service Nginx hôte tourne sur le port 80. Arrêt en cours..."
            $SUDO systemctl stop nginx || true
            $SUDO systemctl disable nginx 2>/dev/null || true
        fi
        if systemctl is-active --quiet apache2 2>/dev/null; then
            log_warning "Un service Apache hôte tourne sur le port 80. Arrêt en cours..."
            $SUDO systemctl stop apache2 || true
            $SUDO systemctl disable apache2 2>/dev/null || true
        fi
        if systemctl is-active --quiet httpd 2>/dev/null; then
            log_warning "Un service HTTPD hôte tourne sur le port 80. Arrêt en cours..."
            $SUDO systemctl stop httpd || true
            $SUDO systemctl disable httpd 2>/dev/null || true
        fi
    fi

    # 3. Vérification si le port 80 est bien libéré
    sleep 2
    if which netstat >/dev/null 2>&1 || which ss >/dev/null 2>&1; then
        local PORT_80_OCCUPIED
        PORT_80_OCCUPIED=$(ss -tulpn 2>/dev/null | grep ':80 ' || true)
        if [ -n "$PORT_80_OCCUPIED" ]; then
            log_warning "Le port 80 semble encore occupé : $PORT_80_OCCUPIED"
        fi
    fi
    log_success "Ports 80 et 443 préparés pour Certbot."
}

# Génération du certificat SSL Let's Encrypt (Mode Standalone)
generate_ssl() {
    log_title "Gestion du Certificat SSL (HTTPS)"
    
    # Charger les variables
    set -a
    [ -f .env ] && . .env
    set +a

    if [ -z "$DOMAIN" ]; then
        log_error "Le DOMAIN n'est pas défini dans .env !"
        exit 1
    fi

    # Création des volumes Docker si inexistants
    docker volume create louemoi_certbot_conf >/dev/null 2>&1 || true
    docker volume create louemoi_certbot_www >/dev/null 2>&1 || true

    # Vérification si un certificat valide existe déjà dans le volume
    local CERT_EXISTS
    CERT_EXISTS=$(docker run --rm -v louemoi_certbot_conf:/etc/letsencrypt alpine sh -c "[ -f /etc/letsencrypt/live/$DOMAIN/fullchain.pem ] && echo 'yes' || echo 'no'")

    if [ "$CERT_EXISTS" = "yes" ]; then
        log_success "Un certificat SSL existe déjà pour le domaine $DOMAIN."
        log_info "Vérification de l'expiration du certificat..."
        docker run --rm -v louemoi_certbot_conf:/etc/letsencrypt certbot/certbot certificates || true
    else
        log_warning "Aucun certificat SSL trouvé pour $DOMAIN."
        
        # Cas particulier : localhost ou IP
        if [ "$DOMAIN" = "localhost" ] || [[ "$DOMAIN" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            log_warning "Le domaine $DOMAIN est une IP ou localhost. Génération d'un certificat SSL auto-signé..."
            generate_self_signed_ssl "$DOMAIN"
        else
            echo -e "${YELLOW}Voulez-vous générer un certificat Let's Encrypt officiel maintenant ? (o/n)${NC}"
            read -r -p "Choix [o] : " SSL_CHOICE
            SSL_CHOICE=${SSL_CHOICE:-o}

            if [[ "$SSL_CHOICE" =~ ^[oOyY]$ ]]; then
                # ARRET TEMPORAIRE DE NGINX POUR LIBERER LE PORT 80
                free_ports_and_stop_nginx

                local STAGING_ARGS=""
                if [ "$SSL_STAGING" = "true" ] || [ "$SSL_STAGING" = "1" ]; then
                    log_warning "Utilisation de l'environnement Let's Encrypt STAGING (tests de quotas)..."
                    STAGING_ARGS="--staging"
                fi

                log_info "Lancement de Certbot en mode STANDALONE sur le port 80..."
                log_info "Domaine ciblé : $DOMAIN | Email : $SSL_EMAIL"

                set +e
                docker run --rm \
                    -p 80:80 \
                    -p 443:443 \
                    -v louemoi_certbot_conf:/etc/letsencrypt \
                    -v louemoi_certbot_www:/var/www/certbot \
                    certbot/certbot certonly \
                    --standalone \
                    -d "$DOMAIN" \
                    --email "$SSL_EMAIL" \
                    --agree-tos \
                    --no-eff-email \
                    --non-interactive \
                    $STAGING_ARGS
                
                CERTBOT_EXIT=$?
                set -e

                if [ $CERTBOT_EXIT -eq 0 ]; then
                    log_success "Certificat SSL Let's Encrypt généré avec succès pour $DOMAIN !"
                else
                    log_error "Échec de l'obtention du certificat Let's Encrypt (Code: $CERTBOT_EXIT)."
                    log_warning "Vérifiez que votre DNS pointe bien l'enregistrement A vers l'IP publique de ce serveur."
                    echo -e "${YELLOW}Génération d'un certificat auto-signé temporaire pour permettre à Nginx de démarrer ? (o/n)${NC}"
                    read -r -p "Choix [o] : " FALLBACK_CHOICE
                    FALLBACK_CHOICE=${FALLBACK_CHOICE:-o}
                    if [[ "$FALLBACK_CHOICE" =~ ^[oOyY]$ ]]; then
                        generate_self_signed_ssl "$DOMAIN"
                    else
                        exit 1
                    fi
                fi
            else
                log_info "Génération d'un certificat auto-signé temporaire..."
                generate_self_signed_ssl "$DOMAIN"
            fi
        fi
    fi

    # Application de la configuration Nginx avec le domaine
    apply_nginx_config "$DOMAIN"
}

# Génération d'un certificat SSL auto-signé temporaire
generate_self_signed_ssl() {
    local DOM="$1"
    log_info "Création d'un certificat auto-signé pour $DOM..."
    
    docker run --rm \
        -v louemoi_certbot_conf:/etc/letsencrypt \
        alpine sh -c "
            apk add --no-cache openssl >/dev/null 2>&1
            mkdir -p /etc/letsencrypt/live/$DOM
            openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
                -keyout /etc/letsencrypt/live/$DOM/privkey.pem \
                -out /etc/letsencrypt/live/$DOM/fullchain.pem \
                -subj '/C=CI/ST=Abidjan/L=Abidjan/O=LoueMoi/OU=Dev/CN=$DOM'
        "
    log_success "Certificat auto-signé créé dans le volume louemoi_certbot_conf."
}

# Génération du fichier de configuration Nginx final
apply_nginx_config() {
    local DOM="$1"
    log_info "Génération de la configuration Nginx pour $DOM..."
    
    mkdir -p nginx/conf.d
    
    # Remplacement des variables dans le template
    sed "s|\${DOMAIN}|$DOM|g" nginx/conf.d/louemoi.conf.template > nginx/conf.d/louemoi.conf
    
    # Supprimer le default.conf pour éviter les conflits d'écoute
    rm -f nginx/conf.d/default.conf
    
    log_success "Fichier nginx/conf.d/louemoi.conf généré."
}

# Sauvegarde de la base de données et des fichiers médias
backup_database_and_media() {
    log_title "Création d'une sauvegarde de sécurité"
    
    mkdir -p backups
    local TIMESTAMP
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    local BACKUP_FILE="backups/louemoi_backup_${TIMESTAMP}.tar.gz"
    local TEMP_DIR="backups/temp_${TIMESTAMP}"

    mkdir -p "$TEMP_DIR"

    # Export Postgres si le conteneur tourne
    if docker ps --format '{{.Names}}' | grep -q "louemoi_db"; then
        log_info "Export de la base de données PostgreSQL..."
        docker exec -t louemoi_db pg_dump -U "${POSTGRES_USER:-louemoi_user}" "${POSTGRES_DB:-louemoi_db}" > "$TEMP_DIR/database.sql" || true
    fi

    # Export des volumes médias et sqlite
    log_info "Sauvegarde des médias utilisateurs..."
    docker run --rm \
        -v louemoi_media_volume:/source_media:ro \
        -v "$PWD/$TEMP_DIR":/backup_dest \
        alpine sh -c "cp -r /source_media /backup_dest/media 2>/dev/null || true"

    tar -czf "$BACKUP_FILE" -C "$TEMP_DIR" .
    rm -rf "$TEMP_DIR"

    log_success "Sauvegarde créée : $BACKUP_FILE ($(du -h "$BACKUP_FILE" | cut -f1))"
}

# Restauration d'une sauvegarde
restore_backup() {
    local BACKUP_FILE="$1"
    if [ -z "$BACKUP_FILE" ] || [ ! -f "$BACKUP_FILE" ]; then
        log_error "Fichier de sauvegarde introuvable : $BACKUP_FILE"
        exit 1
    fi

    log_title "Restauration de la sauvegarde : $BACKUP_FILE"
    echo -e "${RED}${BOLD}ATTENTION : Cela va écraser les données actuelles de la base et des médias !${NC}"
    read -r -p "Êtes-vous absolument sûr ? (tapez 'OUI') : " CONFIRM
    if [ "$CONFIRM" != "OUI" ]; then
        log_info "Restauration annulée."
        exit 0
    fi

    local TEMP_DIR="backups/restore_temp"
    rm -rf "$TEMP_DIR" && mkdir -p "$TEMP_DIR"
    tar -xzf "$BACKUP_FILE" -C "$TEMP_DIR"

    if [ -f "$TEMP_DIR/database.sql" ]; then
        log_info "Restauration de la base de données..."
        cat "$TEMP_DIR/database.sql" | docker exec -i louemoi_db psql -U "${POSTGRES_USER:-louemoi_user}" -d "${POSTGRES_DB:-louemoi_db}"
        log_success "Base de données restaurée."
    fi

    if [ -d "$TEMP_DIR/media" ]; then
        log_info "Restauration des fichiers médias..."
        docker run --rm \
            -v louemoi_media_volume:/dest_media \
            -v "$PWD/$TEMP_DIR/media":/source_media:ro \
            alpine sh -c "cp -r /source_media/* /dest_media/ 2>/dev/null || true"
        log_success "Médias restaurés."
    fi

    rm -rf "$TEMP_DIR"
    log_success "Restauration terminée."
}

# Configuration du cron pour le renouvellement automatique Let's Encrypt
setup_renewal_cron() {
    log_info "Configuration de la tâche de renouvellement automatique SSL..."
    
    local CRON_FILE="/etc/cron.d/louemoi_ssl_renew"
    if [ -d /etc/cron.d ] && [ "$EUID" -eq 0 ]; then
        cat <<EOF > "$CRON_FILE"
# Renouvellement automatique du certificat SSL LoueMoi tous les lundis à 03h00
0 3 * * 1 root cd $SCRIPT_DIR && $DOCKER_COMPOSE run --rm certbot renew --webroot -w /var/www/certbot --quiet && $DOCKER_COMPOSE exec -T nginx nginx -s reload > /dev/null 2>&1
EOF
        chmod 0644 "$CRON_FILE"
        log_success "Tâche Cron de renouvellement SSL installée dans $CRON_FILE."
    else
        log_info "Le conteneur Certbot s'occupe déjà du renouvellement automatique en tâche de fond."
    fi
}

# Configuration du cron quotidien pour les alertes (5 jours) et expirations d'abonnements
setup_expirations_cron() {
    log_info "Configuration de la tâche quotidienne de gestion des abonnements..."
    
    local CRON_FILE="/etc/cron.d/louemoi_check_expirations"
    if [ -d /etc/cron.d ] && [ "$EUID" -eq 0 ]; then
        cat <<EOF > "$CRON_FILE"
# Vérification quotidienne des expirations d'abonnements, alertes à 5 jours et révocation à 02h00
0 2 * * * root cd $SCRIPT_DIR && $DOCKER_COMPOSE exec -T web python manage.py check_expirations > /dev/null 2>&1
EOF
        chmod 0644 "$CRON_FILE"
        log_success "Tâche Cron d'expiration d'abonnements installée dans $CRON_FILE."
    fi
}

# Construction et lancement de la stack Docker
start_stack() {
    log_title "Construction et Démarrage des Conteneurs Docker"
    
    detect_docker_compose
    
    log_info "Construction de l'image Django Backend..."
    $DOCKER_COMPOSE build web

    log_info "Démarrage des services (db, web, nginx, certbot)..."
    $DOCKER_COMPOSE up -d

    log_info "Attente de l'initialisation des conteneurs..."
    sleep 5
    $DOCKER_COMPOSE ps
}

# Vérification de santé (Health Check)
verify_deployment() {
    log_title "Vérification de Santé du Déploiement (Health Check)"
    
    set -a
    [ -f .env ] && . .env
    set +a

    log_info "Attente que l'API Django réponde..."
    local MAX_RETRIES=20
    local COUNT=0
    local SUCCESS=0

    while [ $COUNT -lt $MAX_RETRIES ]; do
        COUNT=$((COUNT + 1))
        # Test direct du conteneur web
        if docker exec louemoi_backend curl -s -f http://localhost:8000/api/properties/ >/dev/null 2>&1; then
            SUCCESS=1
            break
        fi
        echo -n "."
        sleep 2
    done
    echo ""

    if [ $SUCCESS -eq 1 ]; then
        log_success "L'API Django REST répond parfaitement (Code 200/OK) !"
    else
        log_warning "L'API met du temps à répondre. Vérification des logs récents..."
        $DOCKER_COMPOSE logs --tail 30 web
    fi

    # Test Nginx HTTP
    log_info "Test d'accès Nginx..."
    local NGINX_STATUS
    NGINX_STATUS=$(docker exec louemoi_nginx wget -q -O - -S --spider http://127.0.0.1/ 2>&1 | grep "HTTP/" | head -1 || true)
    log_info "Réponse Nginx : ${NGINX_STATUS:-OK}"

    log_title "RÉSUMÉ DU DÉPLOIEMENT"
    echo -e "${GREEN}${BOLD}✔ Application déployée avec succès !${NC}\n"
    echo -e "  🌐 Domaine Principal       : ${BOLD}https://${DOMAIN}${NC}"
    echo -e "  📡 API REST                : ${BOLD}https://${DOMAIN}/api/${NC}"
    echo -e "  📊 Dashboard Admin         : ${BOLD}https://${DOMAIN}/dashboard/${NC}"
    echo -e "  🛠️  Django Admin           : ${BOLD}https://${DOMAIN}/admin/${NC}"
    echo -e "  👤 Superutilisateur Phone  : ${BOLD}${DJANGO_SUPERUSER_PHONE}${NC}"
    echo -e "  🔑 Superutilisateur Pass   : ${BOLD}${DJANGO_SUPERUSER_PASSWORD}${NC}"
    echo -e "  📁 Dossier de Sauvegardes  : ${BOLD}${SCRIPT_DIR}/backups/${NC}\n"
    echo -e "Commandes utiles :"
    echo -e "  - Logs en temps réel : ${CYAN}./deploy.sh --logs${NC}"
    echo -e "  - Sauvegarde manuelle: ${CYAN}./deploy.sh --backup${NC}"
    echo -e "  - Mettre à jour      : ${CYAN}./deploy.sh --update${NC}\n"
}

# Mise à jour continue (Git Pull & Zero/Low-downtime reload)
update_project() {
    log_title "Mise à Jour de l'Application"
    backup_database_and_media

    if [ -d .git ]; then
        log_info "Récupération des dernières modifications Git..."
        git pull --rebase || true
    fi

    log_info "Reconstruction du backend..."
    $DOCKER_COMPOSE build web
    $DOCKER_COMPOSE up -d --no-deps web nginx
    log_success "Mise à jour terminée avec succès."
}

# Menu d'aide
show_help() {
    echo -e "${BOLD}Utilisation : ./deploy.sh [COMMANDE]${NC}\n"
    echo "Commandes disponibles :"
    echo "  (sans argument)      Exécute le déploiement complet interactif (Prérequis, .env, SSL, Docker, Nginx)"
    echo "  --update             Met à jour l'application (sauvegarde, git pull, rebuild, migrations)"
    echo "  --ssl                Génère ou renouvelle le certificat SSL (arrête temporairement Nginx pour Certbot standalone)"
    echo "  --backup             Crée une sauvegarde horodatée de la base Postgres et des médias"
    echo "  --restore <fichier>  Restaure une sauvegarde spécifique"
    echo "  --logs [service]     Affiche les logs en direct (web, nginx, db, certbot)"
    echo "  --status             Affiche l'état des conteneurs et les informations de santé"
    echo "  --check-expirations  Exécute manuellement la vérification des expirations et alertes"
    echo "  --cron               Installe ou met à jour les tâches Cron (SSL et expirations)"
    echo "  --restart            Redémarre l'ensemble de la stack Docker"
    echo "  --stop               Arrête l'ensemble des conteneurs"
    echo "  --clean              Nettoie les images et volumes orphelins non utilisés"
    echo "  --help               Affiche cette aide"
}

# Point d'entrée principal
main() {
    detect_docker_compose

    case "${1:-}" in
        --help|-h)
            show_help
            ;;
        --update)
            update_project
            ;;
        --ssl)
            free_ports_and_stop_nginx
            generate_ssl
            $DOCKER_COMPOSE up -d nginx
            ;;
        --backup)
            backup_database_and_media
            ;;
        --restore)
            restore_backup "${2:-}"
            ;;
        --logs)
            $DOCKER_COMPOSE logs -f "${2:-}"
            ;;
        --status)
            $DOCKER_COMPOSE ps
            echo ""
            docker run --rm -v louemoi_certbot_conf:/etc/letsencrypt certbot/certbot certificates || true
            ;;
        --check-expirations)
            log_info "Exécution de la commande check_expirations..."
            $DOCKER_COMPOSE exec -T web python manage.py check_expirations
            ;;
        --cron)
            setup_renewal_cron
            setup_expirations_cron
            ;;
        --restart)
            log_info "Redémarrage de la stack Docker..."
            $DOCKER_COMPOSE restart
            ;;
        --stop)
            log_info "Arrêt des conteneurs..."
            $DOCKER_COMPOSE down
            ;;
        --clean)
            log_info "Nettoyage du cache Docker..."
            docker system prune -f
            ;;
        *)
            # Déploiement complet standard
            log_title "🚀 DÉPLOIEMENT COMPLET DE L'APPLICATION LOUEMOI"
            install_prerequisites
            configure_firewall
            setup_env
            free_ports_and_stop_nginx
            generate_ssl
            start_stack
            setup_renewal_cron
            setup_expirations_cron
            verify_deployment
            ;;
    esac
}

main "$@"

