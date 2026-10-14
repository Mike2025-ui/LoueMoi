import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'app/app.dart';
import 'core/config/env.dart';
import 'core/services/fcm_service.dart';
import 'firebase_options.dart';

/// Handler d'arrière-plan FCM — DOIT être une fonction top-level (ou
/// statique) annotée `vm:entry-point` pour qu'Android puisse la relancer
/// dans un isolate séparé quand l'app n'est pas au premier plan. Aucune
/// UI/navigation ici : le système affiche déjà la notification depuis le
/// payload `notification` envoyé par Django (voir NotificationService côté
/// backend) ; ce handler existe uniquement pour que le plugin traite
/// correctement les messages reçus en arrière-plan.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Env.load();
  await initializeDateFormatting('fr_FR');
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await _initializeFirebase();
  runApp(const ProviderScope(child: LoueMoiApp()));
}

/// Best-effort : un projet Firebase mal configuré ou une plateforme non
/// supportée ne doit jamais empêcher LoueMoi de démarrer — les modes mock et
/// API restent pleinement fonctionnels sans notifications push.
Future<void> _initializeFirebase() async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    if (kDebugMode) debugPrint('Firebase initialized successfully');
  } catch (e) {
    if (kDebugMode) debugPrint('[Firebase] Initialisation impossible : $e');
    return;
  }
  try {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    if (kDebugMode) debugPrint('[FCM] Handler arrière-plan non enregistré : $e');
  }
  await FcmService().initialize();
}
