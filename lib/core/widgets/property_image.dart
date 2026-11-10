import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/media_url.dart';

/// Affiche une image de propriété, qu'elle vienne d'un asset local (mode
/// démo/mock : `assets/images/...`) ou d'une URL réseau (mode API, backend
/// Django) — même rendu visuel dans les deux cas, avec repli propre si
/// l'image est absente ou indisponible.
class PropertyImage extends StatelessWidget {
  const PropertyImage(
    this.source, {
    super.key,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  final String source;
  final BoxFit fit;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    if (source.isEmpty) return _Fallback(width: width, height: height);

    if (isNetworkMediaSource(source)) {
      return CachedNetworkImage(
        imageUrl: buildMediaUrl(source),
        fit: fit,
        width: width,
        height: height,
        memCacheWidth: (width != null && width!.isFinite && width! > 0) ? (width! * 2).toInt() : 600,
        maxWidthDiskCache: 1200,
        fadeInDuration: const Duration(milliseconds: 150),
        placeholder: (context, url) => Container(
          width: width,
          height: height,
          color: AppColors.surfaceMuted,
        ),
        errorWidget: (context, url, error) => _Fallback(width: width, height: height),
      );
    }

    return Image.asset(
      source,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (context, error, stackTrace) => _Fallback(width: width, height: height),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({this.width, this.height});

  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final isCompact = (height != null && height! < 100) || (width != null && width! < 100);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceMuted,
            AppColors.surfaceMuted.withValues(alpha: 0.85),
          ],
        ),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.home_work_outlined,
            color: AppColors.primary.withValues(alpha: 0.45),
            size: isCompact ? 22 : 36,
          ),
          if (!isCompact) ...[
            const SizedBox(height: 4),
            Text(
              'LoueMoi',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary.withValues(alpha: 0.6),
                letterSpacing: 0.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
