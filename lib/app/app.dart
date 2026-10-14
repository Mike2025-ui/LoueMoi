import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/config/env.dart';
import '../core/constants/app_constants.dart';
import '../core/network/network_providers.dart';
import '../core/services/notification_router.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/models/user.dart';
import '../features/auth/providers/auth_providers.dart';
import '../features/notifications/providers/device_token_providers.dart';
import '../features/notifications/providers/notification_providers.dart';
import '../features/properties/providers/property_providers.dart';
import 'router.dart';
import 'routes.dart';

class LoueMoiApp extends ConsumerStatefulWidget {
  const LoueMoiApp({super.key});

  @override
  ConsumerState<LoueMoiApp> createState() => _LoueMoiAppState();
}

class _LoueMoiAppState extends ConsumerState<LoueMoiApp> with WidgetsBindingObserver {
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<RemoteMessage>? _onMessageOpenedAppSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // USE_MOCK_DATA=true ne doit jamais toucher Firebase — voir la règle
    // mode mock de la mission notifications.
    if (!Env.useMockData) _setUpPushHandling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _onMessageSub?.cancel();
    _onMessageOpenedAppSub?.cancel();
    super.dispose();
  }

  /// Un message reçu pendant que l'app est en arrière-plan (ou terminée)
  /// n'a jamais invalidé les providers (`onMessage` ne se déclenche qu'au
  /// premier plan) — sans ça, rouvrir l'app affichait une liste/un badge
  /// périmés malgré une notification bien créée côté Django. On force donc
  /// un rafraîchissement à chaque retour au premier plan, pour que
  /// l'historique backend (toujours à jour) soit reflété sans délai.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !Env.useMockData) {
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadNotificationsCountProvider);
    }
  }

  /// Foreground : le système n'affiche rien automatiquement quand l'app est
  /// ouverte, donc on montre nous-mêmes une notification visuelle et on
  /// actualise badge/liste. Background (app en arrière-plan, l'utilisateur
  /// clique sur la notification système) et terminée (relancée par un clic,
  /// récupérée via getInitialMessage au démarrage) partagent la même
  /// navigation via [NotificationRouter]. Ne fait jamais planter l'app si
  /// Firebase est indisponible sur cette plateforme/config.
  Future<void> _setUpPushHandling() async {
    try {
      _onMessageSub = FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      _onMessageOpenedAppSub =
          FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) _handleNotificationTap(initialMessage);
    } catch (_) {}
  }

  void _handleForegroundMessage(RemoteMessage message) {
    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadNotificationsCountProvider);

    final notification = message.notification;
    if (notification == null) return;
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text(notification.title ?? notification.body ?? 'Nouvelle notification'),
        action: SnackBarAction(label: 'Voir', onPressed: () => _handleNotificationTap(message)),
      ),
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
    final type = message.data['type']?.toString() ?? '';
    final path = const NotificationRouter().resolvePath(type, message.data);
    if (path != null) ref.read(routerProvider).push(path);

    // Marquage-lu jamais bloquant pour la navigation (même principe que
    // l'écran Notifications in-app) : best-effort, en arrière-plan, une
    // erreur réseau ne doit jamais empêcher d'atteindre la source.
    final notificationId = message.data['notification_id']?.toString();
    if (notificationId != null) {
      markNotificationAsRead(ref, notificationId).catchError((_) {});
    }

    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadNotificationsCountProvider);
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    // Session expirée (401 + refresh KO) détectée par l'AuthInterceptor :
    // déconnexion locale immédiate et retour à l'écran de connexion.
    ref.listen<int>(sessionExpiredProvider, (previous, next) {
      ref.read(authControllerProvider.notifier).forceLogout();
      router.go(AppRoutes.login);
    });

    // Synchronise le token FCM avec Django à chaque transition
    // déconnecté→connecté (login, inscription, restauration de session au
    // démarrage) et le désactive à la transition inverse (déconnexion).
    ref.listen<AsyncValue<User?>>(authControllerProvider, (previous, next) {
      final wasConnected = previous?.valueOrNull != null;
      final isConnected = next.valueOrNull != null;
      if (isConnected && !wasConnected) {
        syncDeviceTokenOnLogin(ref);
      } else if (!isConnected && wasConnected) {
        deactivateDeviceTokenOnLogout(ref);
      }
      // notificationsProvider et favoritesListProvider ne sont pas
      // autoDispose (leur contenu doit survivre à une navigation qui les
      // démonte temporairement) : sans invalidation explicite ici, changer
      // de compte dans la même session app (déconnexion/reconnexion sans
      // redémarrage) laissait apparaître les notifications/favoris de
      // l'utilisateur précédent jusqu'au prochain déclenchement naturel
      // (ouverture de l'écran Notifications, ou un premier ajout/retrait de
      // favori). On force donc leur rafraîchissement à CHAQUE changement de
      // compte, dans les deux sens, comme pour la synchronisation du token
      // FCM ci-dessus.
      if (isConnected != wasConnected) {
        ref.invalidate(notificationsProvider);
        ref.invalidate(unreadNotificationsCountProvider);
        ref.invalidate(favoritesListProvider);
      }
    });

    return MaterialApp.router(
      title: AppConstants.appDisplayName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
      scaffoldMessengerKey: _scaffoldMessengerKey,
    );
  }
}
