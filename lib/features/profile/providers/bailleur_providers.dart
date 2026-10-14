import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/env.dart';
import '../../../core/network/network_providers.dart';
import '../data/bailleur_repository.dart';
import '../models/agent_dashboard.dart';

final bailleurRepositoryProvider = Provider<BailleurRepository>((ref) {
  if (Env.useMockData) return MockBailleurRepository();
  return ApiBailleurRepository(ref.watch(apiClientProvider));
});

final bailleurDashboardProvider = FutureProvider.autoDispose<AgentDashboard>((ref) async {
  final repository = ref.watch(bailleurRepositoryProvider);
  return repository.getDashboard();
});
