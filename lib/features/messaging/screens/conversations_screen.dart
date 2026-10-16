import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/media_url.dart';
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
            return const Center(
              child: Text('Aucune conversation', style: AppTextStyles.caption),
            );
          }
          return ListView.separated(
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
                  onTap: () => context.push(
                    AppRoutes.conversationPath(conversation.id),
                    extra: {'participantName': conversation.participantName},
                  ),
                  leading: CircleAvatar(
                    radius: AppSizes.avatarSm / 2,
                    backgroundColor: AppColors.primaryLight,
                    backgroundImage: conversation.participantPhoto != null
                        ? NetworkImage(buildMediaUrl(conversation.participantPhoto!))
                        : null,
                    child: conversation.participantPhoto == null
                        ? const Icon(Icons.person, color: AppColors.primary)
                        : null,
                  ),
                  title: Text(conversation.participantName, style: AppTextStyles.bodyMedium),
                  subtitle: Text(
                    _lastMessagePreview(conversation.lastMessage),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption,
                  ),
                  trailing: conversation.lastMessage != null
                      ? Text(
                          Formatters.relativeTime(conversation.lastMessage!.createdAt),
                          style: AppTextStyles.small,
                        )
                      : null,
                ),
              );
            },
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
