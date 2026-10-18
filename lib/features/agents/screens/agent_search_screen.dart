import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/feedback.dart';
import '../../../core/utils/media_url.dart';
import '../../auth/providers/auth_providers.dart';
import '../../messaging/providers/message_providers.dart';
import '../models/agent_search_result.dart';
import '../providers/agent_search_providers.dart';

/// GET /api/agents/ — annuaire public d'agents, utilisé depuis l'espace
/// bailleur ("Trouver un agent"). Appeler = téléphonie native uniquement
/// (url_launcher tel:), jamais de VoIP propriétaire.
class AgentSearchScreen extends ConsumerWidget {
  const AgentSearchScreen({super.key});

  Future<void> _call(BuildContext context, String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    final launched = await launchUrl(uri);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible de lancer l'appel.")),
      );
    }
  }

  Future<void> _message(BuildContext context, WidgetRef ref, AgentSearchResult agent) async {
    final currentUser = ref.read(authControllerProvider).valueOrNull;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Veuillez vous connecter pour contacter cet agent.'),
          backgroundColor: AppColors.primary,
          action: SnackBarAction(
            label: 'Se connecter',
            textColor: AppColors.white,
            onPressed: () => context.push(AppRoutes.login),
          ),
        ),
      );
      return;
    }
    if (currentUser.id == agent.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vous ne pouvez pas démarrer une conversation avec vous-même.'),
          backgroundColor: AppColors.primary,
        ),
      );
      return;
    }

    try {
      final repository = ref.read(messageRepositoryProvider);
      final conversationId = await repository.getOrCreateConversationId(agentId: agent.id);
      if (!context.mounted) return;
      context.push(
        AppRoutes.conversationPath(conversationId),
        extra: {'participantName': agent.fullName},
      );
    } catch (e) {
      if (context.mounted) showErrorSnackbar(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(agentSearchResultsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Trouver un agent')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.screenPadding),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, size: 20, color: AppColors.textHint),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextField(
                      onChanged: (v) => ref.read(agentSearchQueryProvider.notifier).state = v,
                      decoration: const InputDecoration(
                        hintText: 'Nom, agence...',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: resultsAsync.when(
              data: (agents) {
                if (agents.isEmpty) {
                  return const Center(
                    child: Text('Aucun agent trouvé.', style: AppTextStyles.caption),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                  itemCount: agents.length,
                  separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) {
                    final agent = agents[index];
                    return _AgentTile(
                      agent: agent,
                      onMessage: () => _message(context, ref, agent),
                      onCall: () => _call(context, agent.phone),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => const Center(
                child: Text('Impossible de charger les agents.', style: AppTextStyles.caption),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AgentTile extends StatelessWidget {
  const _AgentTile({required this.agent, required this.onMessage, required this.onCall});

  final AgentSearchResult agent;
  final VoidCallback onMessage;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primaryLight,
                    backgroundImage: agent.photo != null
                        ? NetworkImage(buildMediaUrl(agent.photo!))
                        : null,
                    child: agent.photo == null
                        ? const Icon(Icons.person, size: 28, color: AppColors.primary)
                        : null,
                  ),
                  if (agent.isVerified)
                    const Positioned(
                      bottom: -2,
                      right: -2,
                      child: CircleAvatar(
                        radius: 9,
                        backgroundColor: AppColors.primary,
                        child: Icon(Icons.check, size: 11, color: AppColors.white),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(agent.fullName, style: AppTextStyles.bodyMedium),
                    if (agent.agencyName.isNotEmpty)
                      Text(agent.agencyName, style: AppTextStyles.caption),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 14, color: AppColors.accent),
                        const SizedBox(width: 2),
                        Text(agent.rating.toStringAsFixed(1), style: AppTextStyles.small),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (agent.description.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(agent.description, style: AppTextStyles.caption),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onMessage,
                  icon: const Icon(Icons.chat_bubble_outline, size: 16),
                  label: const Text('Message'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onCall,
                  icon: const Icon(Icons.call, size: 16, color: AppColors.white),
                  label: const Text('Appeler'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
