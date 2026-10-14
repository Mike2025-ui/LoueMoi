import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/env.dart';
import '../../../core/network/network_providers.dart';
import '../data/agent_search_repository.dart';
import '../models/agent_search_result.dart';

final agentSearchRepositoryProvider = Provider<AgentSearchRepository>((ref) {
  if (Env.useMockData) return MockAgentSearchRepository();
  return ApiAgentSearchRepository(ref.watch(apiClientProvider));
});

final agentSearchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

final agentSearchResultsProvider =
    FutureProvider.autoDispose<List<AgentSearchResult>>((ref) async {
  final repository = ref.watch(agentSearchRepositoryProvider);
  final query = ref.watch(agentSearchQueryProvider).trim();
  return repository.searchAgents(search: query.isEmpty ? null : query);
});
