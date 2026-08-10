import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/property_image.dart';
import '../../properties/providers/property_providers.dart';

class GallerySection {
  const GallerySection({required this.title, required this.images});
  final String title;
  final List<String> images;
}

/// Construit des sections de galerie à partir des photos disponibles pour
/// reproduire la structure Couverture / Chambre / Salon & Terrasse.
List<GallerySection> buildGallerySections(List<String> images) {
  List<String> pick(int start, int count) {
    return List.generate(count, (i) => images[(start + i) % images.length]);
  }

  return [
    GallerySection(title: 'Couverture', images: pick(0, 3)),
    GallerySection(title: 'Chambre', images: pick(3, 3)),
    GallerySection(title: 'Salon & Terrasse', images: pick(1, 3)),
  ];
}

class GalleryScreen extends ConsumerWidget {
  const GalleryScreen({super.key, required this.propertyId});

  final String propertyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propertyAsync = ref.watch(propertyByIdProvider(propertyId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Gallerie')),
      body: propertyAsync.when(
        data: (property) {
          final sections = buildGallerySections(property.images);
          final flatImages = sections.expand((s) => s.images).toList();

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
            children: [
              for (final section in sections) ...[
                const SizedBox(height: AppSpacing.md),
                Text(section.title, style: AppTextStyles.h3),
                const SizedBox(height: AppSpacing.sm),
                _SectionGrid(
                  images: section.images,
                  onTap: (localIndex) {
                    final globalIndex = flatImages.indexOf(section.images[localIndex]);
                    context.push(
                      AppRoutes.propertyGalleryViewerPath(propertyId),
                      extra: {'images': flatImages, 'index': globalIndex < 0 ? 0 : globalIndex},
                    );
                  },
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(
          child: Text('Impossible de charger la galerie.', style: AppTextStyles.caption),
        ),
      ),
    );
  }
}

class _SectionGrid extends StatelessWidget {
  const _SectionGrid({required this.images, required this.onTap});

  final List<String> images;
  final void Function(int index) onTap;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        GestureDetector(
          onTap: () => onTap(0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: AspectRatio(
              aspectRatio: 1.9,
              child: PropertyImage(images[0], fit: BoxFit.cover),
            ),
          ),
        ),
        if (images.length > 1) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: List.generate(images.length - 1, (i) {
              final index = i + 1;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i == images.length - 2 ? 0 : AppSpacing.sm),
                  child: GestureDetector(
                    onTap: () => onTap(index),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: AspectRatio(
                        aspectRatio: 1.4,
                        child: PropertyImage(images[index], fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}
