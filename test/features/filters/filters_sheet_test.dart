import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louemoi/features/filters/screens/filters_sheet.dart';

/// Régression pour le crash reproduit sur téléphone réel :
/// "Tried to modify a provider while the widget tree was building" /
/// "At least one listener of the StateNotifier Instance of
/// `StateController<FilterParams>` threw an exception when the notifier
/// tried to update its state."
///
/// Cause racine : FiltersSheet.initState() appelait
/// `ref.read(draftFilterParamsProvider.notifier).state = ...` de façon
/// synchrone pendant la construction de l'arbre de widgets. Corrigé en
/// dérivant la valeur initiale directement dans la définition du provider
/// (filter_providers.dart) plutôt que de l'écrire depuis initState().
void main() {
  testWidgets('ouvrir FiltersSheet ne lève aucune exception Riverpod', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showFiltersSheet(context),
                  child: const Text('Filtres'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Filtres'));
    // pumpAndSettle déclenche initState() de FiltersSheet — c'est exactement
    // le moment où le crash se produisait avant le correctif.
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Rechercher'), findsOneWidget); // FiltersSheet est bien affiché
    expect(find.text('Réinitialiser'), findsOneWidget);
  });
}
