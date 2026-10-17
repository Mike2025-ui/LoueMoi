import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/circular_icon_button.dart';
import '../../../core/widgets/favorite_button.dart';
import '../../../core/widgets/property_image.dart';
import '../../../core/widgets/share_button.dart';
import '../models/property.dart';

/// En-tête galerie de la page de détail : image principale (PageView),
/// compteur "1/9", miniatures, boutons retour/partage/favoris.
class PropertyImageHeader extends StatefulWidget {
  const PropertyImageHeader({
    super.key,
    required this.property,
    required this.onBack,
    required this.onFavoriteTap,
    required this.onThumbnailsTap,
  });

  final Property property;
  final VoidCallback onBack;
  final VoidCallback onFavoriteTap;
  final VoidCallback onThumbnailsTap;

  @override
  State<PropertyImageHeader> createState() => _PropertyImageHeaderState();
}

class _PropertyImageHeaderState extends State<PropertyImageHeader> {
  final _controller = PageController();
  int _currentIndex = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.property.images;

    return Column(
      children: [
        SizedBox(
          height: 340,
          child: Stack(
            fit: StackFit.expand,
            children: [
              PageView.builder(
                controller: _controller,
                itemCount: images.length,
                onPageChanged: (i) => setState(() => _currentIndex = i),
                itemBuilder: (context, index) {
                  return PropertyImage(images[index], fit: BoxFit.cover);
                },
              ),
              Positioned(
                top: AppSpacing.md,
                left: AppSpacing.screenPadding,
                child: SafeArea(
                  bottom: false,
                  child: CircularIconButton(icon: Icons.arrow_back, onTap: widget.onBack),
                ),
              ),
              Positioned(
                top: AppSpacing.md,
                right: AppSpacing.screenPadding,
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    children: [
                      ShareButton(
                        propertyId: widget.property.id,
                        title: widget.property.title,
                        price: widget.property.price,
                        location: widget.property.locationLabel,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      FavoriteButton(
                        isFavorite: widget.property.isFavorite,
                        onTap: widget.onFavoriteTap,
                      ),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: AppSpacing.md,
                right: AppSpacing.screenPadding,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.overlayDark,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    '${_currentIndex + 1}/${images.length}',
                    style: const TextStyle(color: AppColors.white, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding,
            vertical: AppSpacing.sm,
          ),
          child: SizedBox(
            height: 64,
            child: Row(
              children: List.generate(
                images.length > 4 ? 4 : images.length,
                (index) {
                  final isLastVisible = index == 3 && images.length > 4;
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: index == 3 ? 0 : AppSpacing.sm),
                      child: GestureDetector(
                        onTap: widget.onThumbnailsTap,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              PropertyImage(images[index], fit: BoxFit.cover),
                              if (isLastVisible)
                                Container(
                                  color: AppColors.overlayDark,
                                  alignment: Alignment.center,
                                  child: Text(
                                    '+${images.length - 4}',
                                    style: const TextStyle(
                                      color: AppColors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(images.length, (index) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: index == _currentIndex ? AppColors.primary : AppColors.border,
              ),
            );
          }),
        ),
      ],
    );
  }
}
