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
import '../models/bailleur_search_result.dart';
import '../providers/bailleur_search_providers.dart';

/// GET /api/bailleurs/ — annuaire public de bailleurs, symétrique de
/// AgentSearchScreen (agent → bailleur). Décision métier : un agent peut
/// rechercher un bailleur, consulter son profil public et ses annonces
/// publiques, éventuellement le contacter — jamais de transfert de
/// propriété, jamais de publication au nom d'autrui (voir
/// PropertyViewSet.perform_create côté Django, inchangé).
class BailleurSearchScreen extends ConsumerWidget {
  const BailleurSearchScreen({super.key});

  Future<void> _call(BuildContext context, String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    final launched = await launchUrl(uri);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible de lancer l'appel.")),
      );
    }
  }

  Future<void> _message(BuildContext context, WidgetRef ref, BailleurSearchResult bailleur) async {
    final currentUser = ref.read(authControllerProvider).valueOrNull;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Veuillez vous connecter pour contacter ce bailleur.'),
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
    if (currentUser.id == bailleur.id) {
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
      final conversationId = await repository.getOrCreateConversationId(agentId: bailleur.id);
      if (!context.mounted) return;
      context.push(
        AppRoutes.conversationPath(conversationId),
        extra: {'participantName': bailleur.fullName},
      );
    } catch (e) {
      if (context.mounted) showErrorSnackbar(context, e);
    }
  }

  void _viewProperties(BuildContext context, BailleurSearchResult bailleur) {
    context.push(
      AppRoutes.bailleurPublicPropertiesPath(bailleur.id),
      extra: {'ownerName': bailleur.fullName},
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultsAsync = ref.watch(bailleurSearchResultsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Rechercher un propriétaire')),
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
                      onChanged: (v) => ref.read(bailleurSearchQueryProvider.notifier).state = v,
                      decoration: const InputDecoration(
                        hintText: 'Nom, prénom...',
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
              data: (bailleurs) {
                if (bailleurs.isEmpty) {
                  return const Center(
                    child: Text('Aucun propriétaire trouvé.', style: AppTextStyles.caption),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
                  itemCount: bailleurs.length,
                  separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) {
                    final bailleur = bailleurs[index];
                    return _BailleurTile(
                      bailleur: bailleur,
                      onMessage: () => _message(context, ref, bailleur),
                      onCall: () => _call(context, bailleur.phone),
                      onViewProperties: () => _viewProperties(context, bailleur),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => const Center(
                child: Text('Impossible de charger les propriétaires.', style: AppTextStyles.caption),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BailleurTile extends StatelessWidget {
  const _BailleurTile({
    required this.bailleur,
    required this.onMessage,
    required this.onCall,
    required this.onViewProperties,
  });

  final BailleurSearchResult bailleur;
  final VoidCallback onMessage;
  final VoidCallback onCall;
  final VoidCallback onViewProperties;

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
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primaryLight,
                backgroundImage: bailleur.photo != null
                    ? NetworkImage(buildMediaUrl(bailleur.photo!))
                    : null,
                child: bailleur.photo == null
                    ? const Icon(Icons.person, size: 28, color: AppColors.primary)
                    : null,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(bailleur.fullName, style: AppTextStyles.bodyMedium),
                    const Text('Bailleur', style: AppTextStyles.caption),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onViewProperties,
              icon: const Icon(Icons.apartment_outlined, size: 16),
              label: const Text('Voir ses annonces'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
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
