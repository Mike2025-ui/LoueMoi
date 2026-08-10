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
    // PropertyReviewListCreateView hérite de DefaultPagination (comme
    // /api/properties/) : même enveloppe {count,next,previous,results}.
    final results = response.data!['results'] as List;
    return results
        .map((json) => Review.fromJson(json as Map<String, dynamic>))
        .toList();
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
    return Review.fromJson(response.data!);
  }
}
