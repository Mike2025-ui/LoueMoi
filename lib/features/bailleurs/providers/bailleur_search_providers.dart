import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/env.dart';
import '../../../core/network/network_providers.dart';
import '../data/bailleur_search_repository.dart';
import '../models/bailleur_search_result.dart';

final bailleurSearchRepositoryProvider = Provider<BailleurSearchRepository>((ref) {
  if (Env.useMockData) return MockBailleurSearchRepository();
  return ApiBailleurSearchRepository(ref.watch(apiClientProvider));
});

final bailleurSearchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

final bailleurSearchResultsProvider =
    FutureProvider.autoDispose<List<BailleurSearchResult>>((ref) async {
  final repository = ref.watch(bailleurSearchRepositoryProvider);
  final query = ref.watch(bailleurSearchQueryProvider).trim();
  return repository.searchBailleurs(search: query.isEmpty ? null : query);
});
