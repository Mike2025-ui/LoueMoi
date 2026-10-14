import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louemoi/features/messaging/screens/conversation_screen.dart';

/// Régression pour la barre de saisie de ConversationScreen : 3 boutons
/// média + le champ de texte + le bouton d'envoi ne tenaient plus dans la
/// largeur disponible à 320px, tronquant "Votre message..." en "Votr..."
/// (donnant l'impression visuelle d'une seconde barre de recherche, signalé
/// sur téléphone réel). Un RenderFlex overflow y aurait été le signal
/// déterministe si le problème avait été un débordement plutôt qu'une
/// simple troncature de texte — ce test couvre au moins cette classe de
/// régression aux largeurs demandées.
Future<void> _pumpAt(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    const ProviderScope(
      child: MaterialApp(
        home: ConversationScreen(conversationId: 'conv-1', participantName: 'Mme Kouakou'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final width in [320.0, 360.0, 375.0, 390.0, 412.0]) {
    testWidgets('barre de saisie ConversationScreen ne déborde pas à ${width}px de large',
        (tester) async {
      await _pumpAt(tester, Size(width, 800));
      expect(tester.takeException(), isNull);

      // Les 3 boutons média, le champ de message et le bouton d'envoi
      // doivent tous être présents et atteignables — aucun n'est retiré
      // pour "résoudre" le manque de place.
      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
      expect(find.byIcon(Icons.videocam_outlined), findsOneWidget);
      expect(find.byIcon(Icons.mic_none), findsOneWidget);
      expect(find.byIcon(Icons.send), findsOneWidget);
      expect(find.text('Message...'), findsOneWidget);
    });
  }
}
