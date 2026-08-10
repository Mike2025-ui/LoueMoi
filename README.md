# LoueMoi

Application immobilière (recherche, location, vente) — app Flutter + backend
Django REST Framework.

- `lib/` — application Flutter (Android + iOS)
- `backend/` — API Django REST ([documentation dédiée](backend/README.md))

## 1. Installation backend

```bash
cd backend
python -m venv venv
venv\Scripts\activate            # Windows
# source venv/bin/activate       # macOS/Linux
pip install -r requirements.txt
```

## 2. Installation Flutter

```bash
flutter pub get
```

## 3. Variables d'environnement

Flutter charge sa configuration depuis `assets/env/.env.{development,staging,production}`
(package `flutter_dotenv`), sélectionné au lancement via `--dart-define=ENV=...`
(défaut : `development`). Deux clés :

| Clé | Rôle |
|---|---|
| `API_BASE_URL` | Base des appels API. Laissée vide en dev : résolue automatiquement (`10.0.2.2` émulateur Android, `127.0.0.1` simulateur iOS). |
| `USE_MOCK_DATA` | `true` = repositories mock en mémoire (démo sans backend) ; `false` = vrais appels API Django. |

Surcharge ponctuelle sans éditer les fichiers `.env` :

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000
flutter run --dart-define=USE_MOCK_DATA=true
```

Côté Django, `config/settings.py` lit `DJANGO_SECRET_KEY`, `DJANGO_DEBUG`,
`DJANGO_ALLOWED_HOSTS`, `DJANGO_CORS_ALLOWED_ORIGINS` en variables
d'environnement (valeurs par défaut adaptées au développement local si absentes).

## 4. Migrations

```bash
cd backend
python manage.py migrate
```

## 5. Seed (données de démonstration)

```bash
python manage.py seed_demo_data
```

Crée l'agent démo **Mme Kouakou** (`+2250700000000` / `password123`) et 3
annonces. Rejouable sans risque (`get_or_create`, pas de doublons).

Optionnel, pour l'admin Django (`/admin/`) :

```bash
python manage.py createsuperuser
```

## 6. Lancement Django

```bash
python manage.py runserver
```

Écoute sur `http://127.0.0.1:8000/`.

## 7. Lancement Flutter

Avec le backend réel (assure-toi que `USE_MOCK_DATA=false` dans
`assets/env/.env.development`, déjà le cas par défaut) :

```bash
flutter run --dart-define=ENV=development
```

Sans backend (mode démo, données en mémoire) :

```bash
flutter run --dart-define=USE_MOCK_DATA=true
```

## 8. Configuration Android

- Permission `INTERNET` déclarée dans `android/app/src/main/AndroidManifest.xml`
  (nécessaire y compris en release, pas seulement en debug).
- `android/app/src/main/res/xml/network_security_config.xml` autorise le HTTP
  en clair uniquement vers `10.0.2.2` / `localhost` / `127.0.0.1` (dev local) ;
  toute autre destination reste soumise à HTTPS.
- Orientation verrouillée en portrait (fidélité aux captures de référence).

## 9. Configuration iOS

- `ios/Runner/Info.plist` : exception ATS (`NSAppTransportSecurity`) limitée à
  `localhost`/`127.0.0.1` pour le développement local en HTTP ; HTTPS requis
  partout ailleurs par défaut.
- Orientation verrouillée en portrait.

## 10. Endpoints

Voir le détail complet, la table des filtres et les règles métier dans le
[README du backend](backend/README.md#endpoints).

## 11. Authentification

- JWT (SimpleJWT), identifiant = numéro de téléphone.
- Tokens (access + refresh) stockés uniquement via `flutter_secure_storage`
  (`lib/core/services/auth_storage.dart`) — jamais dans `SharedPreferences`,
  jamais le mot de passe en clair côté client.
- `lib/core/network/auth_interceptor.dart` ajoute automatiquement le Bearer
  token, tente un refresh sur 401 (une seule fois, anti-boucle), et déclenche
  une déconnexion locale si le refresh échoue aussi.
- Au lancement, l'app tente de restaurer la session (`AuthController.ready`)
  avant de choisir Splash → Home ou Splash → Onboarding.

## 12. Tests

```bash
# Flutter — analyse statique + tests unitaires/widgets
flutter analyze
flutter test

# Django — vérifications système
cd backend
python manage.py check
```

Les repositories `Api*Repository` (properties, auth, reservations...) sont
testés avec un `ApiClient` mocké (`mocktail`), sans appel réseau réel : voir
`test/features/*/api_*_repository_test.dart`.
