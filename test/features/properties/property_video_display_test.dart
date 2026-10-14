import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louemoi/features/properties/data/property_repository.dart';
import 'package:louemoi/features/properties/models/agent.dart';
import 'package:louemoi/features/properties/models/property.dart';
import 'package:louemoi/features/properties/models/property_enums.dart';
import 'package:louemoi/features/properties/providers/property_providers.dart';
import 'package:louemoi/features/properties/screens/property_detail_screen.dart';
import 'package:louemoi/features/properties/widgets/property_video_player.dart';

/// Point 2 — vidéo dans les annonces : affichage côté PropertyDetailScreen.
/// La lecture réelle (video_player) dépend d'un canal de plateforme
/// indisponible en environnement de test (flutter test) — sans mock ni
/// appareil, PropertyVideoPlayer bascule alors sur son état d'erreur géré
/// (icône), jamais un crash. Ces tests vérifient donc la présence/absence
/// conditionnelle du lecteur, pas la lecture réelle sur téléphone (voir
/// rapport final, section limitations).
void main() {
  Property makeProperty({String? video}) {
    return Property(
      id: 'p1',
      title: 'Villa test',
      description: 'Une belle villa.',
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
      video: video,
      features: const [],
      amenities: const [],
      agent: const Agent(id: 'a1', firstName: 'Mme', lastName: 'Kouakou', phone: '', whatsapp: ''),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
  }

  Future<void> pump(WidgetTester tester, Property property) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          propertyByIdProvider(property.id).overrideWith((ref) async => property),
          propertyRepositoryProvider.overrideWithValue(MockPropertyRepository()),
        ],
        child: MaterialApp(home: PropertyDetailScreen(propertyId: property.id)),
      ),
    );
  }

  testWidgets('annonce sans vidéo : aucun lecteur affiché, pas d\'espace vide', (tester) async {
    await pump(tester, makeProperty());
    await tester.pumpAndSettle();

    expect(find.byType(PropertyVideoPlayer), findsNothing);
    expect(find.text('Vidéo'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('annonce avec vidéo : le lecteur est affiché', (tester) async {
    await pump(tester, makeProperty(video: 'https://example.com/clip.mp4'));
    await tester.pumpAndSettle();

    expect(find.byType(PropertyVideoPlayer), findsOneWidget);
    expect(find.text('Vidéo'), findsOneWidget);
    // Pas de plugin video_player enregistré en environnement de test : le
    // lecteur bascule sur son état d'erreur géré, jamais une exception.
    expect(tester.takeException(), isNull);
  });

  // Test à l'échelle du widget vidéo lui-même (pas de l'écran entier) :
  // isoler PropertyVideoPlayer garantit que ce test mesure bien la
  // fonctionnalité vidéo indépendamment du reste de l'écran (voir
  // property_detail_screen_layout_test.dart pour le test de layout de
  // l'écran complet, badges/onglets compris).
  for (final width in [320.0, 360.0, 375.0, 390.0, 412.0]) {
    testWidgets('PropertyVideoPlayer : aucun débordement à ${width.toInt()}px', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: width,
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: PropertyVideoPlayer(source: 'https://example.com/clip.mp4'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  }
}
