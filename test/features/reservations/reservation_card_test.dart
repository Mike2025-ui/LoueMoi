import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:louemoi/features/auth/data/auth_repository.dart';
import 'package:louemoi/features/auth/models/user.dart';
import 'package:louemoi/features/auth/models/user_role.dart';
import 'package:louemoi/features/auth/providers/auth_providers.dart';
import 'package:louemoi/features/properties/models/agent.dart';
import 'package:louemoi/features/properties/models/property.dart';
import 'package:louemoi/features/properties/models/property_enums.dart';
import 'package:louemoi/features/properties/providers/property_providers.dart';
import 'package:louemoi/features/reservations/data/reservation_repository.dart';
import 'package:louemoi/features/reservations/models/reservation.dart';
import 'package:louemoi/features/reservations/providers/reservation_providers.dart';
import 'package:louemoi/features/reservations/widgets/reservation_card.dart';

/// Auth minimale pour simuler une session déjà restaurée sur un utilisateur
/// fixe — seule restoreSession() est utilisée par AuthController à la
/// construction, le reste n'a pas besoin d'être implémenté pour ce test.
class _FixedSessionAuthRepository implements AuthRepository {
  const _FixedSessionAuthRepository(this._user);
  final User _user;

  @override
  Future<User?> restoreSession() async => _user;

  @override
  Future<User> login({required String phone, required String password}) =>
      throw UnimplementedError();

  @override
  Future<User> register({
    required String firstName,
    required String lastName,
    required String phone,
    required String password,
    required UserRole role,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> logout() => throw UnimplementedError();

  @override
  Future<void> deactivateAccount(String password) => throw UnimplementedError();

  @override
  Future<void> requestPasswordReset(String phone) => throw UnimplementedError();

  @override
  Future<void> confirmPasswordReset({
    required String phone,
    required String code,
    required String newPassword,
  }) =>
      throw UnimplementedError();

  @override
  Future<User> updateProfile(User current, Map<String, dynamic> changes) =>
      throw UnimplementedError();
}

/// Régression : le bouton "Annuler" d'une réservation en cours doit toujours
/// exister (et rester tappable) après le passage d'un texte seul à une
/// pilule pleine (voir reservation_card.dart), et ne doit jamais apparaître
/// sur une réservation déjà accomplie ou annulée.
void main() {
  // ReservationCard affiche la date via Formatters.shortDate (DateFormat
  // 'd MMM', fr_FR) — sans cette initialisation, le premier test à monter
  // la carte plante avec "Locale data has not been initialized" (jamais
  // nécessaire dans l'app réelle, où main.dart initialise déjà l'intl).
  setUpAll(() async {
    await initializeDateFormatting('fr_FR');
  });

  final property = Property(
    id: 'p1',
    title: 'Studio meublé',
    description: '',
    type: PropertyType.logement,
    category: 'Studio',
    transactionType: TransactionType.location,
    price: 65000,
    city: '',
    commune: 'Cocody',
    district: 'Vallon',
    address: '',
    status: PropertyStatus.disponible,
    images: const [],
    coverImage: '',
    features: const [],
    amenities: const [],
    agent: const Agent(id: 'a1', firstName: 'Mme', lastName: 'Kouakou', phone: '', whatsapp: ''),
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  Reservation reservationWith(ReservationStatus status) => Reservation(
        id: 'res-1',
        propertyId: property.id,
        userId: 'user-1',
        rent: 65000,
        deposit: 0,
        advance: 0,
        status: status,
        createdAt: DateTime(2026, 1, 1),
      );

  Future<void> pumpCard(WidgetTester tester, Reservation reservation) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          propertyByIdProvider(property.id).overrideWith((ref) async => property),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ReservationCard(reservation: reservation, onTap: () {}),
          ),
        ),
      ),
    );
  }

  testWidgets('réservation en cours : le bouton Annuler est présent et tappable', (tester) async {
    await pumpCard(tester, reservationWith(ReservationStatus.enCours));
    await tester.pumpAndSettle();

    expect(find.text('Annuler'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Annuler'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Annuler : état de chargement affiché, et un second appui pendant le chargement '
      "n'appelle le repository qu'une seule fois", (tester) async {
    var callCount = 0;
    final container = ProviderContainer(
      overrides: [
        propertyByIdProvider(property.id).overrideWith((ref) async => property),
        reservationRepositoryProvider
            .overrideWithValue(_CountingDelayedReservationRepository(() => callCount++)),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: ReservationCard(
              reservation: reservationWith(ReservationStatus.enCours),
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Annuler'));
    await tester.pump(); // frame suivant : la requête est en cours
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Annuler'), findsNothing);

    // Deuxième appui pendant le chargement : ignoré (garde _isCancelling).
    // find.ancestor cible précisément l'InkWell du bouton Annuler (celui qui
    // contient l'indicateur de chargement) — pas l'InkWell englobant de
    // toute la carte, qui matcherait aussi find.byType(InkWell) en premier.
    final cancelInkWell = find.ancestor(
      of: find.byType(CircularProgressIndicator),
      matching: find.byType(InkWell),
    );
    await tester.tap(cancelInkWell);
    await tester.pump(const Duration(milliseconds: 100));

    expect(callCount, 1);
    expect(tester.takeException(), isNull);

    // Laisse le délai réseau simulé (200ms) se terminer complètement avant
    // la fin du test — sinon un Timer encore en attente au démontage de
    // l'arbre fait planter le test (invariant flutter_test).
    await tester.pump(const Duration(milliseconds: 150));
  });

  testWidgets('réservation accomplie : aucun bouton Annuler affiché', (tester) async {
    await pumpCard(tester, reservationWith(ReservationStatus.accomplie));
    await tester.pumpAndSettle();

    expect(find.text('Annuler'), findsNothing);
    expect(find.text('Accomplies'), findsOneWidget);
  });

  testWidgets('réservation annulée : aucun bouton Annuler affiché', (tester) async {
    await pumpCard(tester, reservationWith(ReservationStatus.annulee));
    await tester.pumpAndSettle();

    expect(find.text('Annuler'), findsNothing);
    expect(find.text('Annulée'), findsOneWidget);
  });

  group('actions propriétaire (réservation en cours, vue du propriétaire)', () {
    final reservationForOwner = Reservation(
      id: 'res-owner-1',
      propertyId: property.id,
      userId: 'client-1',
      client: const ReservationClient(
        id: 'client-1', firstName: 'Xavier', lastName: 'Issan', phone: '0555', whatsapp: '0555',
      ),
      rent: 65000,
      deposit: 0,
      advance: 0,
      status: ReservationStatus.enCours,
      createdAt: DateTime(2026, 1, 1),
    );

    Future<void> pumpAsOwner(WidgetTester tester) {
      return tester.pumpWidget(
        ProviderScope(
          overrides: [
            propertyByIdProvider(property.id).overrideWith((ref) async => property),
            // property.agent.id == 'a1' : l'utilisateur connecté EST le
            // propriétaire du bien, donc showClientInfo (et les actions
            // propriétaire) doivent s'afficher.
            authRepositoryProvider.overrideWithValue(
              const _FixedSessionAuthRepository(
                User(id: 'a1', firstName: 'Mme', lastName: 'Kouakou', phone: '', whatsapp: ''),
              ),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: ReservationCard(reservation: reservationForOwner, onTap: () {}),
            ),
          ),
        ),
      );
    }

    testWidgets('Discuter, Marquer occupé et Valider sont tous les trois affichés', (tester) async {
      await pumpAsOwner(tester);
      await tester.pumpAndSettle();

      expect(find.text('Discuter'), findsOneWidget);
      expect(find.text('Marquer occupé'), findsOneWidget);
      expect(find.text('Valider'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'régression : "Annuler" n\'est jamais proposé au propriétaire (seul le client '
        'peut annuler sa propre réservation)', (tester) async {
      await pumpAsOwner(tester);
      await tester.pumpAndSettle();

      expect(find.text('Annuler'), findsNothing);
    });

    testWidgets('Valider reste tappable sans exception ni overflow', (tester) async {
      await pumpAsOwner(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Valider'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}

/// Repository factice avec un vrai délai réseau simulé sur cancelReservation
/// (pour observer l'état de chargement du bouton) + un compteur d'appels
/// (pour vérifier la garde anti-double-clic).
class _CountingDelayedReservationRepository extends MockReservationRepository {
  _CountingDelayedReservationRepository(this.onCancelCalled);
  final void Function() onCancelCalled;

  @override
  Future<Reservation> cancelReservation(String id) async {
    onCancelCalled();
    await Future.delayed(const Duration(milliseconds: 200));
    return super.cancelReservation(id);
  }
}
