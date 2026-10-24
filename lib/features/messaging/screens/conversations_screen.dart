import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/media_url.dart';
import '../../auth/providers/auth_providers.dart';
import '../../payments/widgets/subscription_modal.dart';
import '../models/message.dart';
import '../providers/message_providers.dart';

String _lastMessagePreview(Message? message) {
  if (message == null) return '';
  if (message.content.isNotEmpty) return message.content;
  return switch (message.attachmentType) {
    MessageAttachmentType.image => '📷 Photo',
    MessageAttachmentType.video => '🎥 Vidéo',
    MessageAttachmentType.audio => '🎤 Message vocal',
    MessageAttachmentType.text => '',
  };
}

class ConversationsScreen extends ConsumerWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authControllerProvider).valueOrNull;
    if (currentUser == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Messages')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chat_bubble_outline,
                    size: 36,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                const Text(
                  'Connectez-vous pour voir vos messages',
                  style: AppTextStyles.h3,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                const Text(
                  'Échangez directement avec les agents et les propriétaires.',
                  style: AppTextStyles.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                ElevatedButton.icon(
                  onPressed: () => context.push(AppRoutes.login),
                  icon: const Icon(Icons.login, size: 18),
                  label: const Text('Se connecter'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                      vertical: AppSpacing.md,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final conversationsAsync = ref.watch(conversationsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Messages')),
      body: conversationsAsync.when(
        skipLoadingOnReload: true,
        data: (conversations) {
          // Filtrer les conversations sans aucun message (évite les conversations fantômes)
          final activeConversations = conversations.where((c) => c.lastMessage != null).toList();

          if (activeConversations.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => ref.refresh(conversationsProvider.future),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Center(
                    child: Text('Aucune conversation', style: AppTextStyles.caption),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.refresh(conversationsProvider.future),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              itemCount: activeConversations.length,
              separatorBuilder: (context, index) => const Divider(height: 1, indent: 76),
              itemBuilder: (context, index) {
                final conversation = activeConversations[index];
                return Dismissible(
                  key: Key(conversation.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: AppColors.danger,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: AppSpacing.md),
                    child: const Icon(Icons.delete_outline, color: AppColors.white),
                  ),
                  confirmDismiss: (direction) async {
                    return await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Supprimer la conversation ?'),
                        content: Text('Voulez-vous supprimer la conversation avec ${conversation.participantName} ?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Annuler'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Supprimer', style: TextStyle(color: AppColors.danger)),
                          ),
                        ],
                      ),
                    );
                  },
                  onDismissed: (direction) async {
                    try {
                      await ref.read(messageRepositoryProvider).deleteConversation(conversation.id);
                      ref.invalidate(conversationsProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Conversation supprimée.')),
                        );
                      }
                    } catch (_) {
                      ref.invalidate(conversationsProvider);
                    }
                  },
                  child: ListTile(
                    onTap: () async {
                      if (!conversation.canAccess) {
                        final isPro = currentUser.isAgent || currentUser.isBailleur;
                        final subscribed = await showSubscriptionModal(
                          context,
                          isPro: isPro,
                          role: currentUser.role,
                          reason: 'subscription_required',
                        );
                        if (subscribed == true) {
                          ref.invalidate(conversationsProvider);
                        }
                        return;
                      }
                      await context.push(
                        AppRoutes.conversationPath(conversation.id),
                        extra: {'participantName': conversation.participantName},
                      );
                      ref.invalidate(conversationsProvider);
                    },
                    leading: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: AppSizes.avatarSm / 2,
                          backgroundColor: AppColors.primaryLight,
                          backgroundImage: conversation.participantPhoto != null
                              ? NetworkImage(buildMediaUrl(conversation.participantPhoto!))
                              : null,
                          onBackgroundImageError: conversation.participantPhoto != null ? (_, __) {} : null,
                          child: conversation.participantPhoto == null
                              ? const Icon(Icons.person, color: AppColors.primary)
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 13,
                            height: 13,
                            decoration: BoxDecoration(
                              color: conversation.participantIsOnline
                                  ? const Color(0xFF25D366)
                                  : Colors.grey.shade400,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.white, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            conversation.participantName,
                            style: AppTextStyles.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!conversation.canAccess)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.warningBg,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.lock_outline, size: 12, color: AppColors.warningText),
                                SizedBox(width: 3),
                                Text(
                                  'Verrouillée',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.warningText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    subtitle: Row(
                      children: [
                        if (conversation.lastMessage != null &&
                            conversation.lastMessage!.senderId == currentUser.id) ...[
                          if (conversation.lastMessage!.isRead)
                            const Icon(
                              Icons.done_all,
                              size: 16,
                              color: Color(0xFF34B7F1),
                            )
                          else if (conversation.lastMessage!.isDelivered)
                            const Icon(
                              Icons.done_all,
                              size: 16,
                              color: Colors.grey,
                            )
                          else
                            const Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.grey,
                            ),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            _lastMessagePreview(conversation.lastMessage),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(
                              fontWeight: conversation.unreadCount > 0
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: conversation.unreadCount > 0
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (conversation.lastMessage != null)
                          Text(
                            Formatters.relativeTime(conversation.lastMessage!.createdAt),
                            style: AppTextStyles.small,
                          ),
                        if (conversation.unreadCount > 0) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              conversation.unreadCount > 99 ? '99+' : '${conversation.unreadCount}',
                              style: const TextStyle(
                                color: AppColors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(
          child: Text('Impossible de charger les messages.', style: AppTextStyles.caption),
        ),
      ),
    );
  }
}
