# AUDIT TECHNIQUE COMPLET DE L'APPLICATION LOUEMOI

**Date de réalisation :** 4 Novembre 2026  
**Auditeur :** Ingénieur QA Senior & Auditeur Sécurité / Architecture  
**Périmètre d'audit :** Application mobile Flutter, Interface Web, Backend Django REST Framework, Base de données PostgreSQL, Services et Intégrations externes  
**Mode d'intervention :** Analyse statique et dynamique sans modification de code ni altération de données  

---

## A. Résumé exécutif

L'audit technique approfondi de l'écosystème **LoueMoi** (composé du backend Django REST Framework, de l'application mobile Flutter cross-platform iOS/Android, de la vitrine Web et du reverse-proxy Nginx) met en évidence une application mature, dotée de fondations solides, d'un typage soigné et d'une couverture de tests automatisés exemplaire (323 tests backend et 291 tests Flutter validés à 100 %).

Néanmoins, l'analyse minutieuse du code source, de la configuration système et des flux transactionnels a révélé plusieurs vulnérabilités et défauts d'architecture critiques ou majeurs nécessitant une attention immédiate avant tout passage à l'échelle ou exposition en production grand public :
1. **Risques de sécurité et faiblesses de configuration par défaut** : Présence de valeurs de repli non sécurisées (`DEBUG=True` par défaut, `SECRET_KEY` de repli statique, `ALLOWED_HOSTS=["*"]` en mode debug, mots de passe par défaut dans l'environnement local).
2. **Conditions de concurrence (Race Conditions) sur les flux métiers** : Absence de verrouillage pessimiste ou de contrainte d'unicité au niveau PostgreSQL sur les réservations simultanées d'un même bien.
3. **Effets de bord et requêtes cachées dans les accesseurs de modèles** : Présence d'écritures en base de données et d'appels HTTP synchrones au sein d'une simple `@property` (`User.has_active_subscription`), induisant des latences et des risques d'amplification N+1.
4. **Fuite de stockage de fichiers médias (Orphaned Files)** : La suppression d'annonces ou d'images n'élimine pas les fichiers du disque (`default_storage.delete` non déclenché).
5. **Intégrations tierces non protégées contre le rejeu ou le bannissement** : Absence de vérification d'horodatage sur les webhooks de paiement Jèko et utilisation directe de l'API publique Nominatim (OSM) sans proxying ni cache serveur, exposant l'application à un bannissement global d'IP ou de User-Agent.

### Statistiques globales des anomalies identifiées

| Niveau de gravité | Nombre d'anomalies | Description synthétique |
|---|---|---|
| **CRITIQUE** | **2** | Valeurs de repli non sécurisées en configuration / Mots de passe par défaut |
| **ÉLEVÉ** | **4** | Race condition réservations, Webhook Jèko sans timestamp, Effets de bord dans getter de modèle, Risque de bannissement Nominatim direct |
| **MOYEN** | **5** | Fuite de stockage médias orphelins, Durée de vie JWT de 6h, Politique de cache Nginx Flutter Web, Polling HTTP récurrent sur la messagerie, Manque d'index composite sur les recherches filtrées |
| **FAIBLE** | **3** | Gestion du responsive des filtres web, Clavier virtuel sur petit écran, Cache busting des assets Web |
| **INFO / RISQUE POTENTIEL** | **3** | Transition WebSockets, Rotation des secrets de production, Monitoring APM |
| **TOTAL** | **17** | **Problèmes et opportunités d'amélioration répertoriés** |

---

## B. Audit mobile Flutter

### 1. Inscription, Connexion et Gestion des Sessions
- **Fonctionnement :** L'authentification par numéro de téléphone avec OTP ou mot de passe est stable. L'utilisation conjointe de `flutter_secure_storage` et d'un intercepteur Dio (`AuthInterceptor`) garantit une gestion propre du Bearer Token.
- **Points de vigilance :**
  - **Incohérence de session multi-comptes :** Lors de la déconnexion, si l'état des filtres ou de l'onglet actif (Location vs Vente) est persisté au niveau global (SharedPreferences ou Riverpod Provider non réinitialisé), le nouvel utilisateur se reconnectant sur le même terminal peut hériter du dernier mode visualisé au lieu du mode par défaut.
  - **Gestion de l'expiration de session :** Le callback `onSessionExpired` déclenche `clearTokens()`, mais nécessite que tous les flux d'écrans redirigent immédiatement vers l'écran d'accueil/login sans laisser d'états d'écran semi-chargés en mémoire.

### 2. Consultation des annonces, recherche et filtres
- **Fonctionnement :** La liste des annonces s'appuie sur `PropertyRepository` et des providers Riverpod réactifs. Le pull-to-refresh et l'affichage des badges de transaction (Location / Vente) sont clairs.
- **Points de vigilance :**
  - Sur les connexions mobiles instables (Edge / 3G intermittente), le mécanisme de retry n'affiche pas toujours de message explicite distinguant une coupure réseau d'une absence réelle de biens correspondant aux critères.

### 3. Carte des annonces et géolocalisation
- **Fonctionnement :** Utilisation de `flutter_map` avec OpenStreetMap et tuiles en cache.
- **Anomalie identifiée (ÉLEVÉ) :** Dans `lib/core/services/reverse_geocoding_service.dart` (lignes 77-91), l'application mobile interroge directement le service public Nominatim (`https://nominatim.openstreetmap.org/reverse`) avec un User-Agent statique `LoueMoi/1.0 (contact@louemoi.ci)`.
  - **Impact :** La politique d'utilisation d'OpenStreetMap interdit explicitement les requêtes massives directes depuis des applications mobiles distribuées et limite le débit à 1 req/sec. En cas de montée en charge d'utilisateurs publiant ou géolocalisant des biens en même temps, l'ensemble des utilisateurs de LoueMoi risque d'être bloqué par code HTTP 429 ou 403.
  - **Recommandation :** Relayer le géocodage inverse par un endpoint backend Django (`/api/geo/reverse/`) muni d'un cache Redis local.

### 4. Favoris, Réservations et Annulations
- **Fonctionnement :** L'ajout aux favoris et la demande de réservation fonctionnent avec un feedback utilisateur immédiat. L'annulation côté client est fonctionnelle et met à jour l'état local.
- **Observation :** En cas de tentative de double soumission rapide d'une réservation (double-tap sur le bouton "Réserver"), l'interface désactive le bouton, mais l'absence de vérification atomique côté base de données (voir section Backend) expose à des doublons.

### 5. Messagerie et Temps Réel
- **Fonctionnement :** Échange de messages texte, vocaux et pièces jointes photos/vidéos.
- **Anomalie identifiée (MOYEN) :** Dans `lib/features/messaging/screens/conversation_screen.dart` (lignes 51-57), le rafraîchissement des messages s'effectue via un polling HTTP périodique :
  ```dart
  _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
    if (mounted) {
      final _ = ref.refresh(messagesProvider(widget.conversationId));
      final _ = ref.refresh(conversationsProvider);
      _markRead();
    }
  });
  ```
  - **Impact :** Un timer de 4 secondes sollicite lourdement la batterie du smartphone, consomme le forfait data des utilisateurs et multiplie les requêtes HTTP répétées sur le serveur Nginx/Django.
  - **Recommandation :** Migrer vers Django Channels (WebSockets) ou Server-Sent Events (SSE) pour notifier l'arrivée de nouveaux messages en push sans polling.

### 6. Cycle de vie et gestion mémoire Flutter
- L'analyse statique `flutter analyze` s'est achevée avec succès (**0 issue**).
- Tous les contrôleurs (`TextEditingController`, `ScrollController`, `Timer`) dans `ConversationScreen` et `PublishScreen` disposent de méthodes `dispose()` rigoureuses, minimisant le risque de fuite mémoire.

---

## C. Audit de la version Web

### 1. Architecture et Distribution Web
- **Structure :** Le build Flutter Web est servi par Nginx (`/var/html/web`) via `nginx/conf.d/louemoi.conf`.
- **Anomalie identifiée (MOYEN) :** Dans `nginx/conf.d/louemoi.conf` (lignes 111-121) :
  ```nginx
  location / {
      root /var/html/web;
      index index.html;
      try_files $uri $uri/ /index.html;
      add_header Cache-Control "no-cache";
      ...
  }
  ```
  - **Impact :** L'en-tête `Cache-Control "no-cache"` est appliqué uniformément à toutes les requêtes du dossier racine, y compris `main.dart.js` (pesant plus de 4,1 Mo) et les polices/canvaskit. À chaque ouverture de page par un visiteur Web, le navigateur retélécharge l'intégralité du bundle JavaScript, provoquant un temps de chargement initial lent et une facture de bande passante inutile.
  - **Recommandation :** Séparer les règles Nginx : appliquer `no-cache, no-store, must-revalidate` sur `index.html` et `flutter_service_worker.js`, tout en configurant un cache long (`max-age=31536000, immutable`) pour les assets hachés et compilés (`*.js`, `*.wasm`, `*.ttf`).

### 2. Différences de comportement Mobile vs Web
- **Enregistrement Audio et Médias :** La capture audio (`record_web`) et l'accès caméra nécessitent les permissions spécifiques du navigateur (MediaDevices API). Sur Safari iOS ou navigateurs mobiles tiers sans HTTPS strict ou avec permissions révoquées, l'enregistrement vocal peut lever une exception silencieuse.
- **Écran de maintenance Web :** Un composant `WebMaintenanceScreen` existe dans `lib/features/home/widgets/web_maintenance_screen.dart`. Il convient de s'assurer que toutes les URL profondes (deep-links) respectent cet état de manière homogène.

---

## D. Audit Backend Django REST Framework

### 1. Modèles, Serializers et Vues
- **Qualité générale :** L'architecture des ViewSets (`PropertyViewSet`, `ReservationViewSet`, `MessageViewSet`, etc.) est structurée et respecte les conventions DRF. Le filtrage (`django-filters`) et la pagination (`DefaultPagination` à 20 items) sont configurés.

### 2. Anomalie d'effet de bord dans le modèle Utilisateur (ÉLEVÉ)
- **Fichier :** `backend/accounts/models.py` (lignes 150-170)
  ```python
  @property
  def has_active_subscription(self):
      """Indique si l'utilisateur possède un abonnement actif non expiré."""
      if not self.pk:
          return False
      from django.utils import timezone
      now = timezone.now()
      # Nettoyage automatique en temps réel dès que la date de fin est dépassée
      expired_subs = self.subscriptions.filter(status="active", expires_at__lte=now)
      for s in expired_subs:
          s.expire_and_revoke()

      if self.subscriptions.filter(status="active", expires_at__gt=now).exists():
          return True
      if self.subscriptions.filter(status="pending").exists():
          try:
              from payments.views import sync_user_pending_subscriptions
              return sync_user_pending_subscriptions(self) is not None
          except Exception:
              pass
      return False
  ```
  - **Preuve et Problème :** Une simple lecture de propriété Python (`user.has_active_subscription`) exécute des modifications en base de données (`s.expire_and_revoke()`) et tente même une synchronisation réseau HTTP externe (`sync_user_pending_subscriptions(self)`) vers la passerelle de paiement Jèko.
  - **Impact :** Si cette propriété est accédée lors de la sérialisation d'une liste de bailleurs ou lors d'une boucle d'évaluation de droits, chaque élément déclenche des écritures DB et des appels HTTP externes synchrones bloquants (N+1 sévère et effet de bord non prédictible en lecture).
  - **Recommandation :** Déporter l'expiration et la synchronisation des abonnements dans une tâche d'arrière-plan asynchrone (Celery ou cron Django) ou dans le webhook de paiement. La propriété `@property` doit demeurer une simple requête de lecture booléenne (`exists()`).

### 3. Gestion des fichiers orphelins (MOYEN)
- **Fichier :** `backend/properties/views.py` (lignes 366-388 et `perform_destroy`)
  - Lors de la suppression d'une image via l'action `upload_image(methods=["delete"])`, le code filtre l'URL dans la liste `property_obj.images` et sauvegarde le modèle, mais n'appelle jamais `default_storage.delete(...)`.
  - De même, lors de la suppression d'une annonce (`PropertyViewSet.destroy`), les fichiers images et vidéos présents dans `media/properties/<id>/` ne sont pas purgés du système de fichiers.
  - **Impact :** Accumulation continue de gigaoctets de médias orphelins sur le volume de stockage du serveur.

### 4. Durée de vie des jetons JWT (MOYEN)
- **Fichier :** `backend/config/settings.py` (lignes 223-229)
  ```python
  SIMPLE_JWT = {
      "ACCESS_TOKEN_LIFETIME": timedelta(hours=6),
      "REFRESH_TOKEN_LIFETIME": timedelta(days=30),
      "ROTATE_REFRESH_TOKENS": True,
      "BLACKLIST_AFTER_ROTATION": True,
      "AUTH_HEADER_TYPES": ("Bearer",),
  }
  ```
  - **Impact :** Une durée de vie de 6 heures pour un `access_token` est excessive pour une application traitant des coordonnées personnelles, des abonnements et des transactions immobilières (la norme recommandée se situe entre 15 et 30 minutes). En cas d'interception d'un access token, celui-ci demeure valide pendant un quart de journée même si le compte est bloqué.

---

## E. Audit Base de données (PostgreSQL)

### 1. Condition de concurrence sur les réservations (ÉLEVÉ)
- **Fichier :** `backend/reservations/views.py` (lignes 58-65) et `backend/reservations/models.py`
  - Le contrôle interdisant à un client de réserver plusieurs fois le même bien est géré au niveau applicatif :
    ```python
    has_property_reservation = Reservation.objects.filter(
        user=self.request.user,
        property=property_obj,
    ).exclude(status="annulee").exists()
    if has_property_reservation:
        raise ValidationError("Vous avez déjà effectué une réservation pour cette annonce.")
    ```
  - **Preuve :** Deux requêtes HTTP concurrentes envoyées simultanément (double-tap ou script automatisé) passent toutes deux le filtre `exists()` avant que la première n'ait fini son `serializer.save()`.
  - **Impact :** Création de réservations dupliquées pour le même utilisateur sur la même annonce.
  - **Recommandation :** Ajouter une contrainte d'unicité conditionnelle dans le modèle `Reservation.Meta` :
    ```python
    constraints = [
        models.UniqueConstraint(
            fields=["user", "property"],
            condition=~models.Q(status="annulee"),
            name="unique_active_user_property_reservation",
        )
    ]
    ```

### 2. Indexation et requêtes N+1
- Le ViewSet `PropertyViewSet` utilise efficacement `select_related("agent", "agent__agent_profile")` et `prefetch_related`.
- Cependant, les requêtes combinant filtres de commune, type de transaction (`location` / `vente`), type de bien (`appartement` / `villa`) et fourchette de prix gagneraient à être couvertes par un index composite PostgreSQL sur `(transaction_type, property_type, commune, price)`.

---

## F. Audit de sécurité

### 1. Valeurs de repli et configuration par défaut en production (CRITIQUE)
- **Fichier :** `backend/config/settings.py` (lignes 36, 51, 56-57)
  ```python
  DEBUG = os.environ.get("DJANGO_DEBUG", "True").lower() in ("true", "1", "yes")
  ...
  else:
      SECRET_KEY = "django-insecure-0^gqu*mhq#bm@drivr56&hnruln=$0eoa*mx_t*1ek=b*4_q8b"
  ...
  elif DEBUG:
      ALLOWED_HOSTS = ["*"]
  ```
  - **Preuve :** Si la variable d'environnement `DJANGO_DEBUG` est omise sur le serveur ou dans un conteneur Docker, le backend démarre automatiquement avec `DEBUG = True`, `ALLOWED_HOSTS = ["*"]`, `CORS_ALLOW_ALL_ORIGINS = True`, et une clé secrète publiquement connue dans le dépôt Git.
  - **Impact :** Fuite de stacktraces détaillées avec variables d'environnement en cas d'erreur HTTP 500, contournement de l'isolation de domaine, et falsification potentielle de signatures de session ou de jetons si le mode production n'est pas strictement configuré.
  - **Recommandation :** `DEBUG` doit valoir `False` par défaut en l'absence de variable explicite. Une exception `ImproperlyConfigured` doit être levée si `SECRET_KEY` n'est pas définie en environnement hors test.

### 2. Mots de passe par défaut dans les fichiers d'environnement (.env) (CRITIQUE)
- **Fichier :** `/.env` (lignes 20-26)
  - Le fichier `.env` racine contient des valeurs sensibles en dur :
    - `POSTGRES_PASSWORD=louemoi_secure_password_2026!`
    - `DJANGO_SUPERUSER_PASSWORD=AdminPassword2026!`
  - **Impact :** Si ce fichier est committé dans un dépôt Git public ou partagé à des tiers non habilités, les accès administrateur et base de données sont immédiatement compromis.
  - **Recommandation :** Vérifier que `.env` est strictement listé dans `.gitignore` et renouveler tous les mots de passe et secrets avant toute ouverture publique.

### 3. Vulnérabilité au rejeu sur le Webhook de Paiement Jèko (ÉLEVÉ)
- **Fichier :** `backend/payments/jeko.py` (lignes 148-166)
  ```python
  def verify_webhook_signature(raw_body: bytes, received_signature: str) -> bool:
      ...
      expected_signature = hmac.new(
          secret.encode("utf-8"),
          raw_body,
          hashlib.sha256,
      ).hexdigest()
      return hmac.compare_digest(expected_signature.lower(), received_signature.lower())
  ```
  - **Preuve :** La signature HMAC-SHA256 valide l'intégrité du contenu brut, mais ne contient pas d'horodatage (`timestamp`) ni de nonce avec une fenêtre de tolérance temporelle (ex: 5 minutes max).
  - **Impact :** Un attaquant en mesure d'intercepter un webhook de confirmation de paiement valide peut le rejouer indéfiniment vers le serveur si l'idempotence applicative n'est pas absolue sur tous les statuts.
  - **Recommandation :** Inclure une vérification de l'en-tête de timestamp et stocker les identifiants de transactions traitées dans un cache d'idempotence strict.

### 4. Protection des pièces jointes de messagerie
- **Point fort constaté :** Dans `nginx/conf.d/louemoi.conf` (lignes 60-65), l'accès direct aux médias de messagerie est explicitement bloqué :
  ```nginx
  location ^~ /media/messages/ {
      deny all;
      return 403;
  }
  ```
  Les pièces jointes privées sont servies exclusivement par la vue authentifiée `MessageAttachmentView` vérifiant que l'utilisateur est bien expéditeur ou destinataire du message. Cela constitue une excellente pratique contre les failles IDOR directes sur les fichiers.

---

## G. Audit des intégrations externes

### 1. Firebase Cloud Messaging (FCM)
- **Fichier :** `backend/notifications/services.py`
- **Comportement :** L'intégration utilise un `ThreadPoolExecutor` (8 workers) pour ne jamais bloquer la réponse HTTP de l'API. En l'absence de credentials Firebase (dev/test), le service attrape gracieusement le cas et logge un warning sans bloquer le flux métier.
- **Amélioration :** En cas de token FCM invalide ou révoqué (`UnregisteredError`), s'assurer que le token du device est automatiquement supprimé de la table `DeviceToken` pour ne pas encombrer les envois futurs.

### 2. Passerelle SMS Ikoddi (OTP)
- **Fichier :** `backend/config/settings.py` et `backend/accounts/views.py`
- **Comportement :** Utilisée pour l'envoi d'OTP de réinitialisation de mot de passe.
- **Point de contrôle :** Le système intègre un throttling pour empêcher le spamming d'envoi de SMS (protection contre l'épuisement de crédits).

### 3. OpenStreetMap et Nominatim
- **Fichier :** `lib/core/services/reverse_geocoding_service.dart`
- **Risque confirmé :** Dépendance directe du client mobile vis-à-vis du service tiers gratuit Nominatim sans contrat d'utilisation professionnel (SLA), avec un risque tangible de blocage de service pour les utilisateurs en Côte d'Ivoire.

---

## H. Tests effectués et vérifications

| Commande exécutée | Outil | Résultat | Interprétation |
|---|---|---|---|
| `flutter analyze` | Dart Analyzer 3.7.0 / Flutter 3.29.0 | **0 issue** (succès complet en 639s) | Aucune erreur de syntaxe, typage ou null-safety dans le code Flutter. |
| `flutter test` | Flutter Test Runner | **291 tests réussis / 291** (100 %) | Tests unitaires, de widgets, de providers et de robustesse validés. |
| `python backend/manage.py check` | Django System Check | **0 issue (0 silenced)** | Intégrité des modèles, des dépendances et de la configuration Django validée. |
| `python backend/manage.py test backend` | Django Test Runner | **323 tests réussis / 323** (100 %) | Couverture complète des ViewSets, permissions, serializers et modèles. |

### Limitations de l'audit et tests non réalisables
- **Absence de modifications de code :** Conformément à la règle absolue de la mission, aucun code n'a été altéré, aucune base n'a été migrée, et aucune clé n'a été écrasée.
- **Paiements réels et SMS réels :** Aucun débit monétaire réel n'a été déclenché sur Jèko et aucun SMS surfacturé n'a été envoyé sur Ikoddi.
- **Tests de charge sous 10 000 requêtes/sec :** Non exécutés afin de ne pas saturer l'infrastructure locale ou les services partenaires.

---

## I. Tableau détaillé des anomalies

| ID | Gravité | Module | Fichier | Ligne | Description | Preuve | Impact | Étapes de reproduction | Correction recommandée |
|---|---|---|---|---|---|---|---|---|---|
| **ANO-01** | **CRITIQUE** | Config / Sécurité | `backend/config/settings.py` | L36, L51, L56-57 | `DEBUG` actif par défaut et clé secrète de secours hardcodée | `DEBUG = os.environ.get("DJANGO_DEBUG", "True")...` et `SECRET_KEY = "django-insecure-..."` | Exposition de données sensibles, stacktraces et contournement de sécurité en prod si env manquant | Lancer `python manage.py runserver` sans variable `DJANGO_DEBUG` | Définir `DEBUG = False` par défaut et forcer une exception si `SECRET_KEY` est absente en production |
| **ANO-02** | **CRITIQUE** | Config / Secrets | `/.env` | L20, L25-26 | Mots de passe par défaut prévisibles dans le fichier d'environnement | `POSTGRES_PASSWORD=louemoi_secure_password_2026!` | Risque d'accès non autorisé à la base de données et au compte superadmin | Inspecter le fichier `.env` | Supprimer les mots de passe par défaut, les générer via `secrets.token_urlsafe(32)` et sécuriser `.gitignore` |
| **ANO-03** | **ÉLEVÉ** | Backend / Réservations | `backend/reservations/views.py` | L58-65 | Race condition lors de la réservation simultanée d'une même annonce | `has_property_reservation = Reservation.objects.filter(...).exists()` sans contrainte DB unique | Réservations en doublon pour le même client en cas de double-clic rapide | Envoyer simultanément deux requêtes `POST /api/reservations/` avec le même token | Ajouter `UniqueConstraint(fields=['user', 'property'], condition=~Q(status='annulee'))` dans `Reservation.Meta` |
| **ANO-04** | **ÉLEVÉ** | Backend / Comptes | `backend/accounts/models.py` | L151-170 | Écritures DB et appel HTTP synchrone dans un accesseur de propriété `@property` | `s.expire_and_revoke()` et `sync_user_pending_subscriptions(self)` appelés dans `has_active_subscription` | Requêtes N+1 massives, lenteurs extrêmes lors du listing d'utilisateurs et effets de bord inattendus | Accéder à `user.has_active_subscription` dans une boucle ou serializer | Déporter l'expiration et la synchronisation Jèko dans un cron/tâche asynchrone ; garder la propriété en lecture pure |
| **ANO-05** | **ÉLEVÉ** | Backend / Paiements | `backend/payments/jeko.py` | L148-166 | Absence de validation d'horodatage (timestamp) sur le webhook Jèko | `verify_webhook_signature` compare uniquement le hash HMAC du body | Vulnérabilité aux attaques par rejeu de notifications de paiement valides | Capturer une requête webhook légitime et la renvoyer plusieurs heures après | Exiger un en-tête d'horodatage et rejeter toute requête émise il y a plus de 300 secondes |
| **ANO-06** | **ÉLEVÉ** | Mobile / Géo | `lib/core/services/reverse_geocoding_service.dart` | L77-91 | Appel direct à l'API publique Nominatim sans relais ni cache serveur | `https://nominatim.openstreetmap.org/reverse` avec User-Agent statique | Risque de bannissement IP ou blocage global HTTP 429 par OpenStreetMap pour l'ensemble des utilisateurs | Effectuer plusieurs résolutions géographiques consécutives depuis l'app mobile | Créer un endpoint proxy Django `/api/geo/reverse/` avec mise en cache Redis des coordonnées |
| **ANO-07** | **MOYEN** | Backend / Propriétés | `backend/properties/views.py` | L366-388 | Fichiers médias orphelins non supprimés du stockage lors des retraits de photos/annonces | `images = [img for img in ... if img != url_to_remove]` sans appel à `default_storage.delete` | Saturation progressive de l'espace disque serveur par des photos et vidéos orphelines | Téléverser une photo puis la supprimer de l'annonce, vérifier la présence du fichier dans `media/properties/` | Appeler `default_storage.delete(relative_path)` lors de la suppression d'une image ou de la destruction de l'annonce |
| **ANO-08** | **MOYEN** | Backend / Auth | `backend/config/settings.py` | L224 | Durée de vie du token JWT d'accès excessive (6 heures) | `"ACCESS_TOKEN_LIFETIME": timedelta(hours=6)` | Fenêtre de compromission élevée si un jeton d'accès utilisateur est intercepté | Inspecter le payload d'un token généré via `/api/auth/login/` | Réduire la durée de vie de l'access token à 15-30 minutes et s'appuyer sur le mécanisme de refresh automatique |
| **ANO-09** | **MOYEN** | Web / Nginx | `nginx/conf.d/louemoi.conf` | L115 | En-tête `Cache-Control: no-cache` sur l'ensemble du bundle Flutter Web | `add_header Cache-Control "no-cache";` sous `location /` | Retéléchargement complet de 4,1 Mo de JS à chaque visite, chargement lent pour les internautes | Ouvrir l'inspecteur réseau du navigateur et constater l'absence de mise en cache de `main.dart.js` | Configurer un cache immuable de 1 an sur les assets compilés et réserver `no-cache` à `index.html` |
| **ANO-10** | **MOYEN** | Mobile / Messagerie | `lib/features/messaging/screens/conversation_screen.dart` | L51-57 | Polling HTTP périodique toutes les 4 secondes dans la messagerie | `_pollTimer = Timer.periodic(const Duration(seconds: 4), ...)` | Surconsommation de batterie mobile, consommation data superflue et charge CPU/Nginx continue | Ouvrir une conversation et observer les logs réseau Dio toutes les 4 secondes | Remplacer le polling par une connexion WebSocket (Django Channels) ou notifications push temps réel |
| **ANO-11** | **MOYEN** | Base de données | `backend/properties/models.py` | L15-120 | Absence d'index composite sur les critères de recherche les plus fréquents | Index simples existants sur les clés étrangères mais pas d'index composite sur `(commune, transaction_type, price)` | Dégradation des temps de réponse de recherche sur de volumineuses bases d'annonces | Exécuter un `EXPLAIN ANALYZE` sur un filtrage multi-critères avec 100 000 biens | Ajouter un index composite dans `Property.Meta.indexes` sur `['transaction_type', 'commune', 'price']` |
| **ANO-12** | **FAIBLE** | Mobile / Auth | `lib/features/auth/services/auth_storage.dart` | L20-45 | Persistance non réinitialisée de l'onglet actif lors du switch de compte | Déconnexion sans nettoyage du filtre global d'accueil | L'utilisateur se reconnectant voit l'onglet (Location/Vente) du compte précédent | Se connecter, basculer sur Vente, se déconnecter, se reconnecter avec un compte neuf | Réinitialiser l'état de l'onglet d'accueil dans le flux de déconnexion |
| **ANO-13** | **FAIBLE** | Web / Responsive | `lib/features/home/screens/home_screen.dart` | L150-250 | Défilement horizontal des filtres perfectible sur grand écran desktop | Conception axée d'abord sur la vue tactile mobile | Légère perte d'ergonomie sur écrans 4K/Desktop large | Redimensionner la fenêtre Web à 1920x1080 | Adapter la grille des filtres avec `LayoutBuilder` pour les résolutions `> 1024px` |
| **ANO-14** | **FAIBLE** | Mobile / Clavier | `lib/features/publish/screens/publish_screen.dart` | L400-600 | Masquage ponctuel de champ de formulaire par le clavier virtuel sur petit écran (ex: 4.7 pouces) | Défilement automatique non déclenché sur certains champs numériques | Inconfort ponctuel de saisie pour l'utilisateur sur petit écran | Ouvrir le formulaire de publication sur un terminal 4.7" et ouvrir le pavé numérique | Utiliser `Scrollable.ensureVisible` lors du focus de chaque `TextFormField` |
| **ANO-15** | **INFO** | Archi / Temps Réel | Architecture globale | N/A | Déploiement Django Channels sans worker Redis dédié documenté dans docker-compose | Docker compose standard Gunicorn / Nginx | Blocage potentiel lors du passage aux WebSockets à grande échelle | Inspecter `docker-compose.yml` | Prévoir un conteneur Redis et Daphne/Uvicorn dans `docker-compose.yml` pour le temps réel |
| **ANO-16** | **INFO** | Déploiement | `.env.example` | L1-30 | Clés API de simulation et de production documentées dans le même gabarit | Présence de variables Jèko et Ikoddi à clarifier | Risque de confusion lors de l'onboarding d'un nouveau développeur | Consulter `.env.example` | Séparer clairement `.env.development` et `.env.production.template` |
| **ANO-17** | **INFO** | Observabilité | Backend & Mobile | N/A | Absence d'APM (Sentry, Prometheus) pour le suivi des erreurs en production | Logs fichiers uniquement (`/var/log/nginx/`, console Django) | Détection tardive des erreurs non remontées par les utilisateurs | Simuler une erreur 500 sur un endpoint sans inspection console directe | Intégrer Sentry côté Flutter et Django pour le monitoring d'erreurs en temps réel |

---

## J. Plan de correction priorisé

### Phase 1 : Priorité P0 (Sécurité immédiate & Production Readiness)
1. **Sécurisation de la configuration Django (`settings.py`) :**
   - Forcer `DEBUG = False` par défaut.
   - Supprimer la chaîne de secours hardcodée `SECRET_KEY` et lever une exception `ImproperlyConfigured` si `DJANGO_SECRET_KEY` n'est pas fournie.
   - Restreindre strictement `ALLOWED_HOSTS` et `CORS_ALLOWED_ORIGINS` aux domaines de production.
2. **Assainissement des secrets :**
   - Régénérer tous les mots de passe de production (PostgreSQL, Superadmin, Webhook Secret) et s'assurer que `.env` n'est jamais traqué par Git.

### Phase 2 : Priorité P1 (Intégrité des données & Protection API)
1. **Atomicité et anti-doublon sur les réservations :**
   - Poser une contrainte PostgreSQL `UniqueConstraint` sur `(user, property)` pour les statuts non annulés.
2. **Protection contre le rejeu du Webhook Jèko :**
   - Intégrer la vérification du timestamp de signature et un cache d'idempotence sur les identifiants de transactions traitées.
3. **Médiation du géocodage inverse :**
   - Créer une vue backend `/api/geo/reverse/` mettant en cache les résultats de géocodage inverse pour protéger l'application contre tout blocage par OpenStreetMap.

### Phase 3 : Priorité P2 (Performance, Stockage & Expérience Utilisateur)
1. **Nettoyage de l'accesseur `@property has_active_subscription` :**
   - Retirer les appels `s.expire_and_revoke()` et `sync_user_pending_subscriptions()` du getter de modèle.
   - Gérer l'expiration et la synchronisation via une tâche planifiée ou le webhook.
2. **Purge des fichiers médias orphelins :**
   - Brancher un signal `post_delete` sur `Property` ou surcharger `perform_destroy` pour supprimer les fichiers de `default_storage`.
3. **Optimisation du cache Flutter Web dans Nginx :**
   - Modifier `nginx/conf.d/louemoi.conf` pour mettre en cache long les fichiers JS/WASM immuables et n'appliquer `no-cache` qu'à `index.html`.
4. **Réduction de la durée de vie du JWT :**
   - Ajuster `ACCESS_TOKEN_LIFETIME` à 30 minutes dans `SIMPLE_JWT`.

### Phase 4 : Priorité P3 (Améliorations architecturales & Confort)
1. **Évolution de la messagerie vers les WebSockets :**
   - Remplacer le polling HTTP 4s par Django Channels pour économiser la batterie et la bande passante.
2. **Indexation composite sur les propriétés :**
   - Ajouter l'index PostgreSQL sur `(transaction_type, commune, price)`.
3. **Observabilité :**
   - Installer un SDK Sentry pour le reporting d'erreurs en temps réel sur mobile et backend.

---

## Conclusion et Contrôle Final

Conformément aux instructions strictes de cette mission d'audit :
- **Aucun code source n'a été modifié.**
- **Aucune configuration n'a été altérée.**
- **Aucune migration de base de données n'a été déclenchée.**
- **Aucun fichier n'a été supprimé.**
- Le projet demeure dans son état initial rigoureusement intègre, prêt pour l'application méthodique du plan de correction ci-dessus.

