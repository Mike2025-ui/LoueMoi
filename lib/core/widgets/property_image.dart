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
        memCacheWidth: width != null && width!.isFinite ? (width! * 2).toInt() : 600,
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
    return Container(
      width: width,
      height: height,
      color: AppColors.surfaceMuted,
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_not_supported_outlined,
        color: AppColors.textHint,
        size: 28,
      ),
    );
  }
}
