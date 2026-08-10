import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/media_url.dart';
import '../models/agent.dart';

/// Carte agent immobilier (photo, nom, rôle, badge de vérification).
/// Si [onMessageTap] est fourni, une icône de discussion permet de contacter
/// l'agent directement (ouvre l'écran de conversation).
class AgentCard extends StatelessWidget {
  const AgentCard({super.key, required this.agent, this.onMessageTap});

  final Agent agent;
  final VoidCallback? onMessageTap;

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
              const Text('Agent immobilier', style: AppTextStyles.small),
            ],
          ),
        ),
        if (onMessageTap != null)
          Material(
            color: AppColors.primaryLight,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onMessageTap,
              customBorder: const CircleBorder(),
              child: const Padding(
                padding: EdgeInsets.all(10),
                child: Icon(Icons.chat_bubble_outline, size: 20, color: AppColors.primary),
              ),
            ),
          ),
      ],
    );
  }
}
