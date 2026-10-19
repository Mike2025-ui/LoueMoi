import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/media_url.dart';
import '../models/agent.dart';

/// Carte agent immobilier (photo, nom, rôle, badge de vérification).
/// Permet de contacter l'agent via message in-app, appel direct ou WhatsApp.
class AgentCard extends StatelessWidget {
  const AgentCard({
    super.key,
    required this.agent,
    this.onMessageTap,
    this.onCallTap,
    this.onWhatsAppTap,
  });

  final Agent agent;
  final VoidCallback? onMessageTap;
  final VoidCallback? onCallTap;
  final VoidCallback? onWhatsAppTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: AppSizes.avatarSm / 2,
              backgroundColor: AppColors.primary,
              backgroundImage: agent.photo != null
                  ? NetworkImage(buildMediaUrl(agent.photo!))
                  : null,
              child: agent.photo == null
                  ? const Icon(Icons.person, color: AppColors.white, size: 22)
                  : null,
            ),
            if (agent.isVerified)
              const Positioned(
                bottom: -2,
                right: -2,
                child: CircleAvatar(
                  radius: 8,
                  backgroundColor: AppColors.primary,
                  child: Icon(Icons.check, size: 10, color: AppColors.white),
                ),
              ),
          ],
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(agent.shortName, style: AppTextStyles.bodyMedium),
              Text(agent.fullName, style: AppTextStyles.caption),
              Text(agent.roleLabel, style: AppTextStyles.small),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ActionButton(
              icon: Icons.phone_outlined,
              color: AppColors.success,
              backgroundColor: AppColors.successBg,
              tooltip: 'Appel',
              onTap: onCallTap ?? () {},
            ),
            const SizedBox(width: AppSpacing.xs),
            _ActionButton(
              icon: Icons.chat,
              color: const Color(0xFF25D366),
              backgroundColor: const Color(0xFFE8F8EE),
              tooltip: 'WhatsApp',
              onTap: onWhatsAppTap ?? () {},
            ),
            const SizedBox(width: AppSpacing.xs),
            _ActionButton(
              icon: Icons.chat_bubble_outline,
              color: AppColors.primary,
              backgroundColor: AppColors.primaryLight,
              tooltip: 'Conversation',
              onTap: onMessageTap ?? () {},
            ),
          ],
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.color,
    required this.backgroundColor,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: backgroundColor,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: Icon(icon, size: 19, color: color),
          ),
        ),
      ),
    );
  }
}
