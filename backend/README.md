# LoueMoi — Backend Django REST

API REST pour l'application mobile LoueMoi (Flutter). Les chemins exposés ici
correspondent exactement à `lib/core/network/api_endpoints.dart` côté Flutter.

## Démarrage rapide

```bash
cd backend
python -m venv venv
venv\Scripts\activate          # Windows
pip install -r requirements.txt
python manage.py migrate
python manage.py seed_demo_data   # crée un agent démo + 3 annonces
python manage.py createsuperuser  # optionnel, pour /admin/
python manage.py runserver
```

Le serveur écoute sur `http://127.0.0.1:8000/`.

Agent de démonstration créé par `seed_demo_data` :
- téléphone : `+2250700000000`
- mot de passe : `password123`

## Connecter l'app Flutter

Chaque feature Flutter a deux implémentations de son repository :
`Mock*Repository` (données en mémoire) et `Api*Repository` (ce backend). Le
choix se fait via `Env.useMockData` (`lib/core/config/env.dart`), lui-même
piloté par `assets/env/.env.development` (`USE_MOCK_DATA=false` par défaut —
donc déjà branché sur ce serveur) ou par `--dart-define=USE_MOCK_DATA=...`.

`Env.apiBaseUrl` résout automatiquement l'adresse locale en développement
(`10.0.2.2` pour l'émulateur Android, `127.0.0.1` pour le simulateur iOS) —
aucune configuration n'est nécessaire pour du développement local standard.
Pour cibler un autre hôte (device physique, autre machine) :

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000
```

## Endpoints

| Méthode | Chemin | Description |
|---|---|---|
| POST | `/api/auth/register/` | Inscription (nom, prénom, tel, mot de passe) |
| POST | `/api/auth/login/` | Connexion par téléphone + mot de passe |
| POST | `/api/auth/refresh/` | Rafraîchir le token d'accès |
| POST | `/api/auth/logout/` | Blackliste le refresh token |
| GET | `/api/users/me/` | Profil de l'utilisateur connecté |
| GET/POST | `/api/properties/` | Liste (filtrable) / création d'annonces |
| GET/PUT/PATCH/DELETE | `/api/properties/{id}/` | Détail d'une annonce |
| POST | `/api/properties/{id}/favorite/` | Bascule favori |
| GET/POST | `/api/properties/{id}/reviews/` | Avis d'une annonce |
| GET/POST | `/api/reservations/` | Réservations de l'utilisateur connecté |
| POST | `/api/reservations/{id}/cancel/` | Annule (libère la propriété si elle était occupée) |
| GET/POST | `/api/conversations/` | Conversations (client ↔ agent) — get_or_create, idempotent |
| GET/POST | `/api/messages/?conversation={id}` | Messages d'une conversation |

### Filtres et pagination sur `/api/properties/`

`transaction_type`, `type`, `category`, `status`, `is_future`, `commune`,
`district`, `budget_min`, `budget_max` — correspondent un à un à
`FilterParams` côté Flutter. `favorites_only=true` (authentifié) ne renvoie
que les favoris de l'utilisateur connecté — utilisé par l'écran Favoris.

Toutes les listes sont paginées (`?page=`, `?page_size=`, max 100) au format
`{count, next, previous, results}`.

## Règles métier notables

- Créer une réservation passe automatiquement la propriété au statut
  `occupee` (même règle que l'écran de détail Flutter, qui masque le bouton
  "Reserver" pour les biens occupés).
- Les montants (`price`, `rent`, `deposit`, `advance`, `total`...) sont
  sérialisés en nombres JSON (pas en chaînes), pour matcher
  `(json['price'] as num).toDouble()` côté Dart.
- Les valeurs de `Reservation.status` (`enCours`, `accomplie`, `annulee`)
  reprennent exactement les noms de l'enum Dart `ReservationStatus`.

## Prochaines étapes

- Ajouter l'upload d'images (actuellement `images`/`cover_image` sont de
  simples URLs en JSON — `buildMediaUrl()` côté Flutter sait déjà résoudre
  une URL relative type `/media/...` si un `ImageField` est introduit).
- Restreindre les permissions (ex. seul un agent authentifié peut publier).
- Passer sur PostgreSQL et un `.env` (`django-environ` ou équivalent) pour la
  production.
- Notifications : aucune API dédiée pour l'instant (écran Flutter en mock,
  architecture `NotificationRepository` prête pour brancher FCM plus tard).
