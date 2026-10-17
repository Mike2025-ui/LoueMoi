import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louemoi/features/reservations/data/reservation_repository.dart';
import 'package:louemoi/features/reservations/models/reservation.dart';
import 'package:louemoi/features/reviews/data/review_repository.dart';
import 'package:louemoi/features/reviews/models/review.dart';
import 'package:louemoi/features/reviews/widgets/review_card.dart';

void main() {
  group('Règle : Tout le monde peut donner son avis et attribuer des étoiles', () {
    test('MockReviewRepository.addReview enregistre bien la note en étoiles et le commentaire', () async {
      final repository = MockReviewRepository();
      final review = await repository.addReview(
        propertyId: '10',
        comment: 'Très belle maison !',
        rating: 4.5,
      );

      expect(review.propertyId, '10');
      expect(review.rating, 4.5);
      expect(review.comment, 'Très belle maison !');

      final list = await repository.fetchReviews('10');
      expect(list.any((r) => r.id == review.id), isTrue);
    });

    testWidgets('ReviewCard affiche les étoiles et la note sous forme de texte', (tester) async {
      final review = Review(
        id: 'rev-1',
        propertyId: '10',
        userId: 'u1',
        userName: 'Awa Diallo',
        rating: 4.0,
        comment: 'Quartier très calme et sécurisé.',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReviewCard(review: review),
          ),
        ),
      );

      expect(find.text('Awa Diallo'), findsOneWidget);
      expect(find.text('Quartier très calme et sécurisé.'), findsOneWidget);
      expect(find.text('4/5'), findsOneWidget);
      // Doit afficher 4 étoiles pleines et 1 étoile contour
      expect(find.byIcon(Icons.star), findsNWidgets(4));
      expect(find.byIcon(Icons.star_border), findsNWidgets(1));
    });
  });

  group('Règle : Plusieurs réservations possibles mais une seule par publication', () {
    test('MockReservationRepository.createReservation autorise plusieurs réservations sur des biens différents', () async {
      final repository = MockReservationRepository();

      final res1 = await repository.createReservation(
        propertyId: '98',
        rent: 100000,
        deposit: 0,
        advance: 0,
      );
      final res2 = await repository.createReservation(
        propertyId: '99',
        rent: 120000,
        deposit: 0,
        advance: 0,
      );

      expect(res1.propertyId, '98');
      expect(res2.propertyId, '99');
    });

    test('MockReservationRepository.createReservation refuse une 2e réservation sur la même annonce', () async {
      final repository = MockReservationRepository();

      // res-1 est déjà sur propertyId '5'
      expect(
        () => repository.createReservation(
          propertyId: '5',
          rent: 100000,
          deposit: 0,
          advance: 0,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('MockReservationRepository.createReservation réussit sur le même bien après annulation', () async {
      final repository = MockReservationRepository();

      // Annuler la réservation existante sur propertyId '5'
      await repository.cancelReservation('res-1');

      // Maintenant la création sur le bien '5' réussit
      final newRes = await repository.createReservation(
        propertyId: '5',
        rent: 65000,
        deposit: 0,
        advance: 0,
      );

      expect(newRes.propertyId, '5');
      expect(newRes.status, ReservationStatus.enCours);
    });
  });
}

