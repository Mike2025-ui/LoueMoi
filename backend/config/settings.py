"""
Configuration Django du backend LoueMoi.

Prêt à être consommé par l'app Flutter via lib/core/network/api_client.dart
et lib/core/network/api_endpoints.dart (mêmes chemins /api/... des deux côtés).
"""

import os
from datetime import timedelta
from pathlib import Path

import secrets

BASE_DIR = Path(__file__).resolve().parent.parent

# Chargement automatique des variables d'environnement depuis backend/.env si présent
_env_path = BASE_DIR / ".env"
if _env_path.exists():
    try:
        with open(_env_path, encoding="utf-8") as _f:
            for _line in _f:
                _line = _line.strip()
                if _line and not _line.startswith("#") and "=" in _line:
                    _k, _v = _line.split("=", 1)
                    _k = _k.strip()
                    _v = _v.strip().strip("'\"")
                    if _k and _k not in os.environ:
                        os.environ[_k] = _v
    except Exception:
        pass

_SECRET_KEY_ENV = os.environ.get("DJANGO_SECRET_KEY")
_SECRET_FILE = BASE_DIR / ".secret_key"

DEBUG = os.environ.get("DJANGO_DEBUG", "True").lower() in ("true", "1", "yes")

if _SECRET_KEY_ENV:
    SECRET_KEY = _SECRET_KEY_ENV
elif not DEBUG:
    if _SECRET_FILE.exists():
        SECRET_KEY = _SECRET_FILE.read_text().strip()
    else:
        SECRET_KEY = secrets.token_urlsafe(64)
        try:
            _SECRET_FILE.write_text(SECRET_KEY)
            _SECRET_FILE.chmod(0o600)
        except Exception:
            pass
else:
    SECRET_KEY = "django-insecure-0^gqu*mhq#bm@drivr56&hnruln=$0eoa*mx_t*1ek=b*4_q8b"

_raw_allowed = os.environ.get("DJANGO_ALLOWED_HOSTS", "").strip()
if _raw_allowed:
    ALLOWED_HOSTS = [h.strip() for h in _raw_allowed.split(",") if h.strip()]
elif DEBUG:
    ALLOWED_HOSTS = ["*"]
else:
    ALLOWED_HOSTS = ["transfert-online.site", "www.transfert-online.site", "127.0.0.1", "localhost"]


INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    # Tiers
    "rest_framework",
    "rest_framework_simplejwt.token_blacklist",
    "corsheaders",
    "django_filters",
    # Apps LoueMoi
    "accounts",
    "agents",
    "bailleurs",
    "properties",
    "reservations",
    "reviews",
    "messaging",
    "notifications",
    "dashboard",
    "payments",
]

MIDDLEWARE = [
    "corsheaders.middleware.CorsMiddleware",
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "config.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
                "dashboard.context_processors.dashboard_context",
            ],
        },
    },
]

WSGI_APPLICATION = "config.wsgi.application"

# Base de données : bascule automatique sur PostgreSQL si configuré, sinon SQLite
if os.environ.get("POSTGRES_DB"):
    DATABASES = {
        "default": {
            "ENGINE": "django.db.backends.postgresql",
            "NAME": os.environ.get("POSTGRES_DB"),
            "USER": os.environ.get("POSTGRES_USER", "postgres"),
            "PASSWORD": os.environ.get("POSTGRES_PASSWORD", ""),
            "HOST": os.environ.get("POSTGRES_HOST", "db"),
            "PORT": os.environ.get("POSTGRES_PORT", "5432"),
        }
    }
else:
    DATABASES = {
        "default": {
            "ENGINE": "django.db.backends.sqlite3",
            "NAME": BASE_DIR / "db.sqlite3",
        }
    }


AUTH_USER_MODEL = "accounts.User"

AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]

LANGUAGE_CODE = "fr-fr"
TIME_ZONE = "Africa/Abidjan"
USE_I18N = True
USE_TZ = True

STATIC_URL = "static/"
STATIC_ROOT = BASE_DIR / "staticfiles"
MEDIA_URL = "media/"
MEDIA_ROOT = BASE_DIR / "media"

# Point 2 — vidéo dans les annonces : la limite par défaut de Django
# (~2.5 Mo) est trop basse pour un upload vidéo (≤50 Mo, voir
# Property.MAX_VIDEO_SIZE_BYTES). Relevée avec une marge pour l'overhead
# multipart, sans affecter les autres endpoints (photos, restent bien en
# dessous de cette limite).
DATA_UPLOAD_MAX_MEMORY_SIZE = 55 * 1024 * 1024
FILE_UPLOAD_MAX_MEMORY_SIZE = 55 * 1024 * 1024

# --- Dashboard administrateur personnalisé ------------------------------
# Session/authentification Django standard (jamais de JWT ici) : le
# dashboard vit sous /dashboard/, distinct de /admin/ (conservé tel quel) et
# de /api/ (JWT, consommé par Flutter). Un utilisateur non authentifié
# redirigé vers une vue protégée par @login_required/staff_required atterrit
# ici plutôt que sur /admin/login/.
LOGIN_URL = "dashboard:login"

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

# --- Django REST Framework -------------------------------------------------

REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": (
        "rest_framework_simplejwt.authentication.JWTAuthentication",
    ),
    "DEFAULT_PERMISSION_CLASSES": (
        "rest_framework.permissions.IsAuthenticatedOrReadOnly",
    ),
    "DEFAULT_THROTTLE_CLASSES": [
        "rest_framework.throttling.AnonRateThrottle",
        "rest_framework.throttling.UserRateThrottle",
    ],
    "DEFAULT_THROTTLE_RATES": {
        "anon": "300/minute",
        "user": "1200/minute",
        "auth": "30/minute",
    },
    "DEFAULT_FILTER_BACKENDS": ("django_filters.rest_framework.DjangoFilterBackend",),
    "DEFAULT_PAGINATION_CLASS": "config.pagination.DefaultPagination",
    "PAGE_SIZE": 20,
    # Les Decimal (price, deposit, rent...) sont sérialisés en nombres JSON,
    # pas en chaînes, pour matcher `(json['price'] as num)` côté Dart.
    "COERCE_DECIMAL_TO_STRING": False,
}

SIMPLE_JWT = {
    "ACCESS_TOKEN_LIFETIME": timedelta(hours=6),
    "REFRESH_TOKEN_LIFETIME": timedelta(days=30),
    "ROTATE_REFRESH_TOKENS": True,
    "BLACKLIST_AFTER_ROTATION": True,
    "AUTH_HEADER_TYPES": ("Bearer",),
}

# --- Notifications push (FCM) -------------------------------------------
# FIREBASE_CREDENTIALS_JSON : contenu JSON complet du compte de service
# Firebase (Console Firebase > Paramètres du projet > Comptes de service >
# Générer une nouvelle clé privée), fourni comme variable d'environnement —
# JAMAIS un fichier committé dans Git. Lu directement par
# notifications/services.py (os.environ.get), pas ici : cette section ne
# sert qu'à documenter la variable attendue. Absente en dev : les
# notifications restent créées en base, seul le push FCM est sauté.

# --- Passerelle SMS OTP (IKODDI) -----------------------------------------
# Configuration de la passerelle SMS Ikoddi pour l'envoi d'OTP
# de réinitialisation de mot de passe ("Mot de passe oublié").
# Les valeurs sont lues depuis l'environnement sur le serveur de production.
IKODDI_API_KEY = os.environ.get("IKODDI_API_KEY") or os.environ.get("IKKODI_API_KEY", "")
IKODDI_SENDER_ID = os.environ.get("IKODDI_SENDER_ID") or os.environ.get("IKKODI_SENDER_ID", "LoueMoi")
IKODDI_API_URL = os.environ.get("IKODDI_API_URL") or os.environ.get("IKKODI_API_URL", "https://api.ikoddi.com/v1/sms/send")

# --- Passerelle de Paiement & Abonnements (Jèko Checkout) ------------------
# Clés API et Webhook Jèko (https://jeko.africa / https://mcp.jeko.africa)
# Pour les abonnements mensuels :
# - Bailleur / Agent : 3 000 FCFA / mois
# - Client : 1 000 FCFA / mois (si bailleur non abonné)
JEKO_API_KEY = os.environ.get("JEKO_API_KEY", "")
JEKO_API_KEY_ID = os.environ.get("JEKO_API_KEY_ID", "")
JEKO_STORE_ID = os.environ.get("JEKO_STORE_ID", "")
JEKO_WEBHOOK_SECRET = os.environ.get("JEKO_WEBHOOK_SECRET", "")
JEKO_API_URL = os.environ.get("JEKO_API_URL", "https://api.jeko.africa")


# --- CORS --------------------------------------------------------------
# Dev uniquement : l'app mobile n'a pas d'origine web à restreindre.
CORS_ALLOW_ALL_ORIGINS = DEBUG
CORS_ALLOWED_ORIGINS = [
    origin
    for origin in os.environ.get("DJANGO_CORS_ALLOWED_ORIGINS", "").split(",")
    if origin
]

# --- Sécurité & Reverse Proxy (Nginx / SSL) ------------------------------
SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
USE_X_FORWARDED_HOST = True
USE_X_FORWARDED_PORT = True

_raw_csrf = os.environ.get("DJANGO_CSRF_TRUSTED_ORIGINS", "").strip()
if _raw_csrf:
    CSRF_TRUSTED_ORIGINS = [origin.strip() for origin in _raw_csrf.split(",") if origin.strip()]
else:
    CSRF_TRUSTED_ORIGINS = [
        "https://transfert-online.site",
        "https://www.transfert-online.site",
    ]

if not DEBUG:
    SESSION_COOKIE_SECURE = True
    CSRF_COOKIE_SECURE = True
    SESSION_COOKIE_HTTPONLY = True
    CSRF_COOKIE_HTTPONLY = True
    SECURE_BROWSER_XSS_FILTER = True
    SECURE_CONTENT_TYPE_NOSNIFF = True
    X_FRAME_OPTIONS = "DENY"

