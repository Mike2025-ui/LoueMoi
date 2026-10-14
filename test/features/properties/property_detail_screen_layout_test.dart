import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louemoi/features/properties/data/property_repository.dart';
import 'package:louemoi/features/properties/models/agent.dart';
import 'package:louemoi/features/properties/models/property.dart';
import 'package:louemoi/features/properties/models/property_enums.dart';
import 'package:louemoi/features/properties/providers/property_providers.dart';
import 'package:louemoi/features/properties/screens/property_detail_screen.dart';

/// Régression pour deux RenderFlex overflow réels sur PropertyDetailScreen,
/// reproduits par ce test AVANT correction :
///
/// 1. La Row(spaceBetween) des badges catégorie + "il y a X" (ligne ~126)
///    ne protégeait aucun des deux enfants — débordement à 320px (49px) et
///    360px (9.3px) avec un titre/badge de longueur réaliste. Corrigé en
///    Wrap(alignment: WrapAlignment.spaceBetween).
/// 2. La Row des 3 onglets A propos/Gallerie/Avis (ligne ~191) laissait
///    chaque _TabButton se dimensionner à son contenu naturel — débordement
///    aux 5 largeurs testées, y compris 412px (31px, le plus persistant des
///    deux). Corrigé avec un Expanded par onglet (même principe que
///    MainBottomNav).
void main() {
  Property makeProperty() {
    return Property(
      id: 'p1',
      // Titre volontairement long : c'est la combinaison
      // titre-long + date-relative-longue qui déclenchait le débordement
      // de la première Row aux largeurs les plus étroites.
      title: 'Bel appartement meublé avec vue sur la lagune',
      description: 'Une belle villa avec beaucoup de détails à propos du logement proposé.',
      type: PropertyType.logement,
      category: 'Villa',
      transactionType: TransactionType.location,
      price: 500000,
      city: 'Abidjan',
      commune: 'Cocody',
      district: 'Vallon',
      address: '',
      status: PropertyStatus.disponible,
      images: const ['https://example.com/photo1.jpg'],
      coverImage: 'https://example.com/photo1.jpg',
      features: const [],
      amenities: const [],
      agent: const Agent(id: 'a1', firstName: 'Mme', lastName: 'Kouakou', phone: '', whatsapp: ''),
      createdAt: DateTime.now().subtract(const Duration(days: 40)),
      updatedAt: DateTime.now(),
    );
  }

  Future<void> pumpAt(WidgetTester tester, Property property, double width) async {
    await tester.binding.setSurfaceSize(Size(width, 900));
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          propertyByIdProvider(property.id).overrideWith((ref) async => property),
          propertyRepositoryProvider.overrideWithValue(MockPropertyRepository()),
        ],
        child: MaterialApp(home: PropertyDetailScreen(propertyId: property.id)),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final width in [320.0, 360.0, 375.0, 390.0, 412.0]) {
    testWidgets('PropertyDetailScreen ne déborde pas à ${width.toInt()}px de large',
        (tester) async {
      await pumpAt(tester, makeProperty(), width);

      expect(tester.takeException(), isNull);

      // Rien n'a été perdu pour "corriger" l'overflow : titre, badges et
      // les 3 onglets restent bien tous affichés.
      expect(find.text('Bel appartement meublé avec vue sur la lagune'), findsOneWidget);
      expect(find.text('Villa'), findsOneWidget);
      expect(find.text('A propos'), findsOneWidget);
      expect(find.text('Gallerie'), findsOneWidget);
      expect(find.text('Avis'), findsOneWidget);
    });
  }
}
