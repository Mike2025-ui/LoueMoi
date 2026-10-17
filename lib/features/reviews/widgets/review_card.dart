import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/media_url.dart';
import '../models/review.dart';

class ReviewCard extends StatelessWidget {
  const ReviewCard({super.key, required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: AppSizes.avatarSm / 2,
            backgroundColor: AppColors.primaryLight,
            backgroundImage: review.userPhoto != null
                ? NetworkImage(buildMediaUrl(review.userPhoto!))
                : null,
            child: review.userPhoto == null
                ? const Icon(Icons.person, color: AppColors.primary, size: 20)
                : null,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(review.userName, style: AppTextStyles.bodyMedium),
                    Text(
                      'Il y a ${Formatters.relativeTime(review.createdAt)}',
                      style: AppTextStyles.small,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    ...List.generate(5, (index) {
                      final starNum = index + 1;
                      return Icon(
                        starNum <= review.rating.round()
                            ? Icons.star
                            : Icons.star_border,
                        size: 16,
                        color: Colors.amber,
                      );
                    }),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '${review.rating.toStringAsFixed(review.rating.truncateToDouble() == review.rating ? 0 : 1)}/5',
                      style: AppTextStyles.caption.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                if (review.comment.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(review.comment, style: AppTextStyles.body),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
