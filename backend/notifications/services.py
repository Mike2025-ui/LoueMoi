"""Service FCM isolé — jamais de logique Firebase directement dans les
ViewSets (properties/messaging/reviews/reservations n'importent que
`NotificationService.notify`, rien d'autre).

Comportement sans credentials Firebase (FIREBASE_CREDENTIALS_JSON absente,
ou package firebase-admin non installé) : la Notification est quand même
créée en base, le push est simplement sauté avec un warning loggé — jamais
d'exception remontée à l'appelant, jamais de blocage d'une opération métier
(réservation, message, avis) à cause d'un souci FCM.
"""

import json
import logging
import os
import sys
from concurrent.futures import ThreadPoolExecutor
from django.conf import settings
from django.db import transaction

from .models import DeviceToken, Notification

logger = logging.getLogger(__name__)
_push_executor = ThreadPoolExecutor(max_workers=8, thread_name_prefix="fcm_push")

try:
    import firebase_admin
    from firebase_admin import credentials as firebase_credentials
    from firebase_admin import messaging as firebase_messaging
except ImportError:  # pragma: no cover - environnement sans firebase-admin
    firebase_admin = None
    firebase_credentials = None
    firebase_messaging = None

_firebase_app = None
_firebase_app_init_attempted = False


def _get_firebase_app():
    """Initialise Firebase Admin une seule fois (mise en cache).
    Cherche en priorité le fichier sécurisé backend/firebase-credentials.json (/app/firebase-credentials.json)
    ou la variable d'environnement FIREBASE_CREDENTIALS_JSON."""
    global _firebase_app, _firebase_app_init_attempted

    if firebase_admin is None:
        return None
    if _firebase_app is not None:
        return _firebase_app
    try:
        _firebase_app = firebase_admin.get_app()
        return _firebase_app
    except (ValueError, Exception):
        pass

    # 1. Vérification en priorité du fichier physique de service account
    file_candidates = [
        "/app/firebase-credentials.json",
        os.path.join(getattr(settings, "BASE_DIR", ""), "firebase-credentials.json"),
        os.path.join(os.path.dirname(getattr(settings, "BASE_DIR", "")), "firebase-credentials.json"),
    ]
    for path in file_candidates:
        if path and os.path.isfile(path):
            try:
                cred = firebase_credentials.Certificate(path)
                _firebase_app = firebase_admin.initialize_app(cred)
                logger.info(f"Firebase Admin initialisé avec succès depuis le fichier : {path}")
                return _firebase_app
            except Exception:
                logger.warning(f"Impossible d'initialiser Firebase Admin depuis le fichier {path}.", exc_info=True)

    # 2. Repli sur la variable d'environnement FIREBASE_CREDENTIALS_JSON
    credentials_json = os.environ.get("FIREBASE_CREDENTIALS_JSON", "").strip()
    if not credentials_json:
        if not _firebase_app_init_attempted:
            logger.info(
                "Aucun fichier firebase-credentials.json ni FIREBASE_CREDENTIALS_JSON configuré."
            )
            _firebase_app_init_attempted = True
        return None

    try:
        cred = firebase_credentials.Certificate(json.loads(credentials_json))
        _firebase_app = firebase_admin.initialize_app(cred)
        logger.info("Firebase Admin initialisé avec succès depuis FIREBASE_CREDENTIALS_JSON.")
        return _firebase_app
    except Exception:
        logger.warning("Impossible d'initialiser Firebase Admin depuis FIREBASE_CREDENTIALS_JSON.", exc_info=True)
        return None


def _is_unregistered_token_error(exc) -> bool:
    """Détecte les erreurs FCM signifiant que le token n'est plus valide
    (application désinstallée, token expiré...) pour le désactiver."""
    if firebase_messaging is None:
        return False
    return isinstance(
        exc,
        (
            firebase_messaging.UnregisteredError,
            getattr(firebase_messaging, "SenderIdMismatchError", ()),
        ),
    )


class NotificationService:
    """Point d'entrée unique pour créer une notification métier. Ne JAMAIS
    appeler firebase_admin directement ailleurs dans le code."""

    @staticmethod
    def notify(
        recipient,
        notif_type,
        title,
        body="",
        data=None,
        property=None,
        reservation=None,
        conversation=None,
        actor=None,
    ):
        """Garde-fou centralisé : l'acteur d'une action ne doit jamais
        recevoir sa propre notification (ex: un client qui réserve n'est
        pas notifié de sa propre réservation ; un agent qui envoie un
        message n'est pas notifié de son propre message). Chaque appelant
        doit passer `actor` (l'utilisateur qui a déclenché l'événement) dès
        qu'il est connu — silencieusement no-op si recipient == actor,
        plutôt que de laisser chaque site d'appel réimplémenter ce contrôle."""
        if actor is not None and recipient is not None and actor.pk == recipient.pk:
            return None

        notification = Notification.objects.create(
            recipient=recipient,
            type=notif_type,
            title=title,
            body=body,
            data=data or {},
            property=property,
            reservation=reservation,
            conversation=conversation,
        )
        # Le push n'est tenté qu'après validation définitive de la
        # transaction DB en cours (si on est dans un bloc atomic) — une
        # réservation/un message ne doit jamais être annulé à cause d'un
        # souci FCM, et on n'envoie jamais un push pour une opération qui
        # aurait finalement été annulée (rollback). `_send_push` gère déjà
        # ses propres erreurs, mais ce filet de sécurité supplémentaire
        # garantit qu'AUCUNE exception ne peut jamais s'échapper de ce
        # callback, quoi qu'il arrive à l'intérieur.
        transaction.on_commit(lambda: NotificationService._safe_send_push(notification))
        return notification

    @staticmethod
    def _safe_send_push(notification):
        if "test" in sys.argv:
            try:
                NotificationService._send_push(notification)
            except Exception:
                logger.warning(
                    "Erreur inattendue lors de l'envoi du push pour la notification %s.",
                    notification.id,
                    exc_info=True,
                )
            return

        def _task():
            try:
                NotificationService._send_push(notification)
            except Exception:
                logger.warning(
                    "Erreur inattendue lors de l'envoi du push pour la notification %s.",
                    notification.id,
                    exc_info=True,
                )

        try:
            _push_executor.submit(_task)
        except Exception:
            _task()

    @staticmethod
    def _send_push(notification):
        try:
            app = _get_firebase_app()
            if app is None:
                return

            tokens = list(
                DeviceToken.objects.filter(
                    user=notification.recipient, is_active=True
                ).values_list("token", flat=True)
            )
            if not tokens:
                return

            data_payload = {"type": notification.type}
            data_payload.update({k: str(v) for k, v in (notification.data or {}).items()})
            # Ajouté APRÈS le .update() ci-dessus : ne doit jamais pouvoir
            # être écrasé par un data{} fourni par l'appelant. Sans cet id,
            # Flutter ne peut pas marquer CETTE notification comme lue au
            # clic sur un push réel (_handleNotificationTap, app.dart) —
            # seul le clic depuis l'écran Notifications in-app le pouvait
            # jusqu'ici.
            data_payload["notification_id"] = str(notification.id)

            android_config = firebase_messaging.AndroidConfig(
                priority="high",
                notification=firebase_messaging.AndroidNotification(
                    sound="default",
                    default_sound=True,
                    default_vibrate_timings=True,
                    notification_priority="PRIORITY_MAX",
                    visibility="public",
                ),
            )
            apns_config = firebase_messaging.APNSConfig(
                payload=firebase_messaging.APNSPayload(
                    aps=firebase_messaging.Aps(
                        sound="default",
                        badge=1,
                    )
                )
            )

            message = firebase_messaging.MulticastMessage(
                notification=firebase_messaging.Notification(
                    title=notification.title, body=notification.body
                ),
                android=android_config,
                apns=apns_config,
                data=data_payload,
                tokens=tokens,
            )
            response = firebase_messaging.send_each_for_multicast(message, app=app)

            for token, result in zip(tokens, response.responses):
                if not result.success and _is_unregistered_token_error(result.exception):
                    DeviceToken.objects.filter(token=token).update(is_active=False)
        except Exception:
            # Ne jamais laisser une erreur FCM remonter — la notification
            # est déjà en base, c'est tout ce qui est garanti.
            logger.warning(
                "Échec d'envoi du push FCM pour la notification %s.",
                notification.id,
                exc_info=True,
            )

    @staticmethod
    def broadcast(recipients_qs, title: str, body: str, data: dict | None = None) -> dict:
        """Envoie une notification groupée (in-app + push FCM temps réel sur téléphone)
        à tous les utilisateurs du QuerySet `recipients_qs`.

        Retourne un dictionnaire récapitulatif :
        `{"users_count": int, "devices_count": int}`.
        """
        recipient_ids = list(recipients_qs.values_list("id", flat=True))
        if not recipient_ids:
            return {"users_count": 0, "devices_count": 0}

        payload_data = dict(data or {})
        payload_data.setdefault("type", Notification.TYPE_ADMIN_BROADCAST)

        notif_objs = [
            Notification(
                recipient_id=uid,
                type=Notification.TYPE_ADMIN_BROADCAST,
                title=title,
                body=body,
                data=payload_data,
            )
            for uid in recipient_ids
        ]
        Notification.objects.bulk_create(notif_objs, batch_size=500)

        active_tokens = list(
            DeviceToken.objects.filter(
                user_id__in=recipient_ids, is_active=True
            ).values_list("token", flat=True)
        )

        def _send_multicast_batches():
            try:
                app = _get_firebase_app()
                if app is None or not active_tokens:
                    return
                str_data = {"type": Notification.TYPE_ADMIN_BROADCAST}
                str_data.update({k: str(v) for k, v in payload_data.items()})

                android_config = firebase_messaging.AndroidConfig(
                    priority="high",
                    notification=firebase_messaging.AndroidNotification(
                        sound="default",
                        default_sound=True,
                        default_vibrate_timings=True,
                        notification_priority="PRIORITY_MAX",
                        visibility="public",
                    ),
                )
                apns_config = firebase_messaging.APNSConfig(
                    payload=firebase_messaging.APNSPayload(
                        aps=firebase_messaging.Aps(
                            sound="default",
                            badge=1,
                        )
                    )
                )

                # FCM send_each_for_multicast accepte jusqu'à 500 tokens par lot
                for i in range(0, len(active_tokens), 500):
                    chunk = active_tokens[i : i + 500]
                    message = firebase_messaging.MulticastMessage(
                        notification=firebase_messaging.Notification(
                            title=title, body=body
                        ),
                        android=android_config,
                        apns=apns_config,
                        data=str_data,
                        tokens=chunk,
                    )
                    response = firebase_messaging.send_each_for_multicast(message, app=app)
                    for tok, res in zip(chunk, response.responses):
                        if not res.success and _is_unregistered_token_error(res.exception):
                            DeviceToken.objects.filter(token=tok).update(is_active=False)
            except Exception:
                logger.warning("Échec lors de la diffusion push FCM groupée.", exc_info=True)

        if "test" in sys.argv:
            _send_multicast_batches()
        else:
            try:
                _push_executor.submit(_send_multicast_batches)
            except Exception:
                _send_multicast_batches()

        return {
            "users_count": len(recipient_ids),
            "devices_count": len(active_tokens),
        }
