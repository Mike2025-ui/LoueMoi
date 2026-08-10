import '../models/review.dart';

abstract class ReviewRepository {
  Future<List<Review>> fetchReviews(String propertyId);
  Future<Review> addReview({
    required String propertyId,
    required String comment,
    required double rating,
  });
}

class MockReviewRepository implements ReviewRepository {
  final Map<String, List<Review>> _reviewsByProperty = {
    '1': [
      Review(
        id: 'r1',
        propertyId: '1',
        userId: 'u1',
        userName: 'François Rodriguez',
        rating: 5,
        comment: 'Très beau logement, propre et bien entretenu. '
            "L'emplacement est idéal et le quartier est calme. Je recommande vivement.",
        createdAt: DateTime.now().subtract(const Duration(days: 14)),
      ),
    ],
  };

  @override
  Future<List<Review>> fetchReviews(String propertyId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _reviewsByProperty[propertyId] ?? [];
  }

  @override
  Future<Review> addReview({
    required String propertyId,
    required String comment,
    required double rating,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final review = Review(
      id: 'r-${DateTime.now().millisecondsSinceEpoch}',
      propertyId: propertyId,
      userId: 'current-user',
      userName: 'Vous',
      rating: rating,
      comment: comment,
      createdAt: DateTime.now(),
    );
    _reviewsByProperty.putIfAbsent(propertyId, () => []).insert(0, review);
    return review;
  }
}
