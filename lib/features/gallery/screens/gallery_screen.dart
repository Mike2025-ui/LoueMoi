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

/// Construit des sections de galerie réelles par catégorie
/// (Couverture, Chambre, Salon & Terrasse, Cuisine, Salle(s) de bain)
/// sans JAMAIS dupliquer de photo entre les sections.
List<GallerySection> buildGallerySections(List<String> images) {
  if (images.isEmpty) return const [];

  final couverture = <String>[];
  final chambres = <String>[];
  final salon = <String>[];
  final cuisine = <String>[];
  final salleDeBain = <String>[];
  final autres = <String>[];

  // Détecter si les images possèdent des marqueurs de catégorie
  bool hasCategoryTags = false;
  for (final img in images) {
    final lower = img.toLowerCase();
    if (lower.contains('cat_couverture') ||
        lower.contains('cat_chambre') ||
        lower.contains('cat_salon') ||
        lower.contains('cat_cuisine') ||
        lower.contains('cat_salledebain') ||
        lower.contains('couverture_') ||
        lower.contains('chambre_') ||
        lower.contains('salon_') ||
        lower.contains('cuisine_') ||
        lower.contains('salledebain_')) {
      hasCategoryTags = true;
      break;
    }
  }

  if (hasCategoryTags) {
    for (final img in images) {
      final lower = img.toLowerCase();
      if (lower.contains('couverture')) {
        couverture.add(img);
      } else if (lower.contains('chambre')) {
        chambres.add(img);
      } else if (lower.contains('salon')) {
        salon.add(img);
      } else if (lower.contains('cuisine')) {
        cuisine.add(img);
      } else if (lower.contains('salledebain') || lower.contains('salle_de_bain') || lower.contains('bain')) {
        salleDeBain.add(img);
      } else {
        autres.add(img);
      }
    }
  } else {
    // Annonces existantes créées sans tag : 1re photo en couverture, reste en chambre(s)
    couverture.add(images.first);
    if (images.length > 1) {
      chambres.addAll(images.skip(1));
    }
  }

  final sections = <GallerySection>[];
  if (couverture.isNotEmpty) {
    sections.add(GallerySection(title: 'Couverture', images: couverture));
  }
  if (chambres.isNotEmpty) {
    sections.add(GallerySection(title: 'Chambre(s)', images: chambres));
  }
  if (salon.isNotEmpty) {
    sections.add(GallerySection(title: 'Salon & Terrasse', images: salon));
  }
  if (cuisine.isNotEmpty) {
    sections.add(GallerySection(title: 'Cuisine', images: cuisine));
  }
  if (salleDeBain.isNotEmpty) {
    sections.add(GallerySection(title: 'Salle(s) de bain', images: salleDeBain));
  }
  if (autres.isNotEmpty) {
    sections.add(GallerySection(title: 'Autres photos', images: autres));
  }

  return sections;
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

          if (sections.isEmpty) {
            return const Center(
              child: Text('Aucune photo disponible pour cette annonce.', style: AppTextStyles.caption),
            );
          }

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
