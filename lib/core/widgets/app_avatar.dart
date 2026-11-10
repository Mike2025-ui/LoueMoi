import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/media_url.dart';

/// Avatar utilisateur résilient et haute performance :
/// - Utilise [CachedNetworkImage] pour le cache mémoire et disque.
/// - En cas d'erreur de chargement (404, hors-ligne), bascule immédiatement
///   sur les initiales de l'utilisateur avec fond coloré au lieu de rester vide.
/// - Gère l'état de chargement lors de l'upload et le badge d'édition.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.photoUrl,
    required this.initials,
    this.radius = 28,
    this.isUploading = false,
    this.showEditBadge = false,
    this.isVerified = false,
    this.onTap,
  });

  final String? photoUrl;
  final String initials;
  final double radius;
  final bool isUploading;
  final bool showEditBadge;
  final bool isVerified;
  final VoidCallback? onTap;

  Widget _buildInitials() {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary.withValues(alpha: 0.12),
      child: Text(
        initials.isNotEmpty ? initials : '?',
        style: TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.75,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cleanUrl = (photoUrl ?? '').trim();
    final hasValidUrl = cleanUrl.isNotEmpty && isNetworkMediaSource(cleanUrl);

    Widget avatar;
    if (isUploading) {
      avatar = CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.surfaceMuted,
        child: SizedBox(
          width: radius,
          height: radius,
          child: const CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    } else if (!hasValidUrl) {
      avatar = _buildInitials();
    } else {
      avatar = CachedNetworkImage(
        imageUrl: buildMediaUrl(cleanUrl),
        imageBuilder: (context, imageProvider) => CircleAvatar(
          radius: radius,
          backgroundImage: imageProvider,
          backgroundColor: AppColors.surfaceMuted,
        ),
        placeholder: (context, url) => CircleAvatar(
          radius: radius,
          backgroundColor: AppColors.surfaceMuted,
          child: SizedBox(
            width: radius * 0.8,
            height: radius * 0.8,
            child: const CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ),
        errorWidget: (context, url, error) => _buildInitials(),
      );
    }

    if (showEditBadge || isVerified || onTap != null) {
      avatar = GestureDetector(
        onTap: isUploading ? null : onTap,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            avatar,
            if (showEditBadge)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.camera_alt,
                    size: radius * 0.35,
                    color: AppColors.white,
                  ),
                ),
              )
            else if (isVerified)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.white, width: 2),
                  ),
                  child: Icon(
                    Icons.check,
                    size: radius * 0.35,
                    color: AppColors.white,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return avatar;
  }
}
