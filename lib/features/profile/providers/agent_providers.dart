import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/env.dart';
import '../../../core/network/network_providers.dart';
import '../data/agent_repository.dart';
import '../models/agent_dashboard.dart';

final agentRepositoryProvider = Provider<AgentRepository>((ref) {
  if (Env.useMockData) return MockAgentRepository();
  return ApiAgentRepository(ref.watch(apiClientProvider));
});

final agentDashboardProvider = FutureProvider.autoDispose<AgentDashboard>((ref) async {
  final repository = ref.watch(agentRepositoryProvider);
  return repository.getDashboard();
});
