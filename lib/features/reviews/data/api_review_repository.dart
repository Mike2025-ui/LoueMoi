import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../models/review.dart';
import 'review_repository.dart';

/// Implémentation réelle, branchée sur `/api/properties/{id}/reviews/`.
class ApiReviewRepository implements ReviewRepository {
  ApiReviewRepository(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<List<Review>> fetchReviews(String propertyId) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.propertyReviews(propertyId),
      query: {'page_size': 100},
    );
    final data = response.data;
    if (data == null) return const [];
    final rawResults = data['results'] ?? data;
    if (rawResults is! List) return const [];
    final results = <Review>[];
    for (final item in rawResults) {
      if (item is Map) {
        try {
          results.add(Review.fromJson(Map<String, dynamic>.from(item)));
        } catch (_) {}
      }
    }
    return results;
  }

  @override
  Future<Review> addReview({
    required String propertyId,
    required String comment,
    required double rating,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.propertyReviews(propertyId),
      data: {'comment': comment, 'rating': rating},
    );
    if (response.data == null) {
      return Review(
        id: '',
        propertyId: propertyId,
        userId: '',
        userName: 'Moi',
        rating: rating,
        comment: comment,
        createdAt: DateTime.now(),
      );
    }
    return Review.fromJson(response.data!);
  }
}
