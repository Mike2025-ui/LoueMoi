import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/routes.dart';
import '../../../core/services/notification_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/feedback.dart';
import '../../../core/utils/formatters.dart';
import '../models/app_notification.dart';
import '../providers/notification_providers.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);

    final isDesktopWeb = MediaQuery.of(context).size.width >= 768;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        automaticallyImplyLeading: false,
        leading: Navigator.canPop(context)
            ? const BackButton()
            : (!isDesktopWeb
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: () => context.go(AppRoutes.home),
                  )
                : null),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                await markAllNotificationsAsRead(ref);
              } catch (e) {
                if (context.mounted) showErrorSnackbar(context, e);
              }
            },
            child: const Text('Tout lire', style: AppTextStyles.link),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: notificationsAsync.when(
            data: (notifications) {
              if (notifications.isEmpty) {
                return const Center(
                  child: Text('Aucune notification', style: AppTextStyles.caption),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                itemCount: notifications.length,
                separatorBuilder: (context, index) => const Divider(height: 1, indent: 72),
                itemBuilder: (context, index) {
              final notification = notifications[index];
              return _NotificationTile(
                notification: notification,
                onTap: () async {
                  // Marquer comme lu et naviguer sont deux actions
                  // indépendantes : si le marquage échoue (réseau instable
                  // sur téléphone réel), l'utilisateur doit quand même
                  // pouvoir atteindre la conversation/réservation/propriété
                  // concernée plutôt que de rester bloqué sur une exception
                  // silencieuse (c'était le cas ici auparavant — un échec de
                  // markNotificationAsRead empêchait aussi bien la mise à
                  // jour du badge que la navigation).
                  try {
                    await markNotificationAsRead(ref, notification.id);
                  } catch (e) {
                    if (context.mounted) showErrorSnackbar(context, e);
                  }
                  if (!context.mounted) return;
                  final path = const NotificationRouter()
                      .resolvePath(notification.rawType, notification.data);
                  if (path != null) {
                    if (path == AppRoutes.notifications) {
                      if (!context.mounted) return;
                      showDialog<void>(
                        context: context,
                        builder: (dialogCtx) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                          ),
                          title: Text(notification.title, style: AppTextStyles.h3),
                          content: SingleChildScrollView(
                            child: Text(
                              notification.message,
                              style: AppTextStyles.body.copyWith(height: 1.5),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(dialogCtx).pop(),
                              child: const Text('Fermer'),
                            ),
                          ],
                        ),
                      );
                    } else if (path == AppRoutes.reservationsList) {
                      context.go(path);
                    } else {
                      context.push(path);
                    }
                  } else {
                    // Type inconnu ou données insuffisantes pour retrouver
                    // la source (ex: property_id manquant) : ne jamais
                    // naviguer au hasard ni planter, mais le dire clairement
                    // plutôt que de ne rien faire silencieusement.
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Impossible d'ouvrir cette notification.")),
                    );
                  }
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(
          child: Text('Impossible de charger les notifications.',
              style: AppTextStyles.caption),
        ),
      ),
    ),
  ),
);
}
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  ({IconData icon, Color color}) get _visual => switch (notification.type) {
        NotificationType.message => (icon: Icons.chat_bubble_outline, color: AppColors.primary),
        NotificationType.reservation => (icon: Icons.event_available_outlined, color: AppColors.success),
        NotificationType.favorite => (icon: Icons.favorite_outline, color: AppColors.favoriteActive),
        NotificationType.system => (icon: Icons.info_outline, color: AppColors.accent),
      };

  @override
  Widget build(BuildContext context) {
    final visual = _visual;
    return InkWell(
      onTap: onTap,
      child: Container(
        color: notification.isRead ? Colors.transparent : AppColors.primaryLight.withValues(alpha: 0.4),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPadding,
          vertical: AppSpacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: visual.color.withValues(alpha: 0.12),
              child: Icon(visual.icon, color: visual.color, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(notification.title, style: AppTextStyles.bodyMedium),
                      ),
                      if (!notification.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(left: AppSpacing.sm),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(notification.message, style: AppTextStyles.caption),
                  const SizedBox(height: 4),
                  Text(
                    Formatters.relativeTime(notification.createdAt),
                    style: AppTextStyles.small,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
