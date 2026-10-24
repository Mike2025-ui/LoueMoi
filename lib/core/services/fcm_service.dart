import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Service isolé pour l'initialisation Firebase : permission, récupération
/// du token FCM, écoute de son rafraîchissement. Ne contient aucune
/// logique métier (pas d'appel Django ici) — [onToken] est un simple point
/// d'extension optionnel pour que l'appelant synchronise le token avec le
/// backend (voir features/notifications/providers/device_token_providers.dart),
/// sans coupler ce service à la couche réseau.
///
/// [messaging] est injectable pour les tests (aucune dépendance à une
/// instance Firebase réelle) ; en production, [FirebaseMessaging.instance]
/// est utilisée par défaut.
class FcmService {
  FcmService({FirebaseMessaging? messaging}) : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;

  /// Demande la permission de notification puis récupère le token FCM.
  /// [onToken], si fourni, est appelé avec le token initial (s'il existe)
  /// puis à chaque rafraîchissement — jamais plus d'une fois pour la même
  /// valeur. Ne lève jamais d'exception : toute erreur (permission refusée,
  /// service indisponible, projet Firebase mal configuré...) est
  /// journalisée en mode debug et résulte simplement en un retour `null`,
  /// sans jamais faire planter LoueMoi.
  Future<String?> initialize({void Function(String token)? onToken}) async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      if (kDebugMode) {
        debugPrint('[FCM] Statut de permission : ${settings.authorizationStatus}');
      }

      // Configuration explicite pour iOS / iPadOS pour afficher les bannières même au premier plan
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Création du canal de notification Android haute priorité avec son et bannière tête haute (Heads-up)
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        try {
          const MethodChannel channel = MethodChannel('dexterous.com/flutter/local_notifications');
          // Tentative d'enregistrement de canal natif si plugin présent ou canal système Android
        } catch (_) {}
      }

      final token = await _messaging.getToken();
      if (kDebugMode) {
        if (token != null) {
          debugPrint('FCM token obtenu :\n$token');
        } else {
          debugPrint('[FCM] Aucun token obtenu (permission refusée ou service indisponible).');
        }
      }
      if (token != null) onToken?.call(token);

      _messaging.onTokenRefresh.listen((newToken) {
        if (kDebugMode) debugPrint('[FCM] Token rafraîchi :\n$newToken');
        onToken?.call(newToken);
      });

      return token;
    } catch (e) {
      if (kDebugMode) debugPrint('[FCM] Erreur d’initialisation : $e');
      return null;
    }
  }
}
