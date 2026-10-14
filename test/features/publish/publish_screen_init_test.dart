import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louemoi/features/publish/screens/publish_screen.dart';

/// Régression pour le crash Riverpod reproduit sur téléphone réel : pour une
/// nouvelle publication (pas une édition), PublishScreen.initState()
/// appelait _loadInitial() qui mutait publishFormProvider de façon
/// synchrone (avant tout `await`) — donc pendant la construction de l'arbre
/// de widgets. Corrigé en reportant l'appel à addPostFrameCallback.
void main() {
  testWidgets('ouvrir PublishScreen pour une nouvelle annonce ne lève aucune exception Riverpod',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: PublishScreen()),
      ),
    );
    // Le premier pump construit l'arbre (initState), le second laisse le
    // postFrameCallback s'exécuter — c'est exactement le moment où le crash
    // se produisait avant le correctif.
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
