import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/env.dart';
import '../../../core/network/network_providers.dart';
import '../data/api_review_repository.dart';
import '../data/review_repository.dart';
import '../models/review.dart';

final reviewRepositoryProvider = Provider<ReviewRepository>((ref) {
  if (Env.useMockData) return MockReviewRepository();
  return ApiReviewRepository(ref.watch(apiClientProvider));
});

final reviewsByPropertyProvider =
    FutureProvider.family<List<Review>, String>((ref, propertyId) async {
  final repository = ref.watch(reviewRepositoryProvider);
  return repository.fetchReviews(propertyId);
});

Future<void> addReview(
  WidgetRef ref, {
  required String propertyId,
  required String comment,
  double rating = 5,
}) async {
  final repository = ref.read(reviewRepositoryProvider);
  await repository.addReview(propertyId: propertyId, comment: comment, rating: rating);
  ref.invalidate(reviewsByPropertyProvider(propertyId));
}
