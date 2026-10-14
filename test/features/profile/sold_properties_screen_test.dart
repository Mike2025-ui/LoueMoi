import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louemoi/features/profile/screens/sold_properties_screen.dart';
import 'package:louemoi/features/properties/models/agent.dart';
import 'package:louemoi/features/properties/models/property.dart';
import 'package:louemoi/features/properties/models/property_enums.dart';
import 'package:louemoi/features/properties/providers/property_providers.dart';

/// "Propriétés vendues" réutilise myPropertiesProvider (déjà scopé côté
/// serveur) et filtre côté Flutter — ces tests vérifient uniquement ce
/// filtrage, jamais une deuxième source de données.
void main() {
  Property makeProperty({
    required String id,
    required String title,
    required TransactionType transactionType,
    required PropertyStatus status,
  }) {
    return Property(
      id: id,
      title: title,
      description: '',
      type: PropertyType.logement,
      category: 'Villa',
      transactionType: transactionType,
      price: 50000000,
      city: '',
      commune: 'Cocody',
      district: 'Vallon',
      address: '',
      status: status,
      images: const [],
      coverImage: '',
      features: const [],
      amenities: const [],
      agent: const Agent(id: 'a1', firstName: 'Mme', lastName: 'Kouakou', phone: '', whatsapp: ''),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
  }

  final soldVilla = makeProperty(
    id: 'p1', title: 'Villa vendue',
    transactionType: TransactionType.vente, status: PropertyStatus.vendue,
  );
  final availableVilla = makeProperty(
    id: 'p2', title: 'Villa disponible',
    transactionType: TransactionType.vente, status: PropertyStatus.disponible,
  );
  final occupiedStudio = makeProperty(
    id: 'p3', title: 'Studio occupé',
    transactionType: TransactionType.location, status: PropertyStatus.occupee,
  );

  Future<void> pump(WidgetTester tester, List<Property> myProperties) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [myPropertiesProvider.overrideWith((ref) async => myProperties)],
        child: const MaterialApp(home: SoldPropertiesScreen()),
      ),
    );
  }

  testWidgets('affiche uniquement les biens vente + vendue', (tester) async {
    await pump(tester, [soldVilla, availableVilla, occupiedStudio]);
    await tester.pumpAndSettle();

    expect(find.text('Vendue'), findsOneWidget);
    expect(find.byType(GridView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('aucune propriété vendue : état vide, sans exception', (tester) async {
    await pump(tester, [availableVilla, occupiedStudio]);
    await tester.pumpAndSettle();

    expect(find.text('Aucune propriété vendue pour le moment.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
