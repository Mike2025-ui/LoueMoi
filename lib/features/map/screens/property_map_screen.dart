import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../app/routes.dart';
import '../../../core/services/location_permission_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/feedback.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_map_view.dart';
import '../../../core/widgets/property_image.dart';
import '../../../core/widgets/status_badge.dart';
import '../../properties/models/property.dart';
import '../../properties/providers/property_providers.dart';
import '../providers/map_providers.dart';

const List<double> _radiusOptionsKm = [0, 5, 10, 20];

/// Carte immobilière plein écran (section 15 du cahier des charges) —
/// annonces publiques avec position, recherche à proximité par rayon.
/// Réutilise PropertyCard/PropertyDetailScreen tels quels : aucune nouvelle
/// identité visuelle.
class PropertyMapScreen extends ConsumerStatefulWidget {
  const PropertyMapScreen({super.key});

  @override
  ConsumerState<PropertyMapScreen> createState() => _PropertyMapScreenState();
}

class _PropertyMapScreenState extends ConsumerState<PropertyMapScreen> {
  final _mapController = MapController();
  bool _resolvingLocation = true;
  String? _locationNotice;

  // Abidjan, Cocody — centre de repli si la position GPS est indisponible ou
  // refusée : la carte reste utilisable, jamais un écran cassé.
  static const _defaultCenter = LatLng(5.359951, -4.008256);

  @override
  void initState() {
    super.initState();
    _resolveInitialLocation();
  }

  Future<void> _resolveInitialLocation() async {
    final result = await const LocationPermissionService().getCurrentPosition();
    if (!mounted) return;
    if (result.isSuccess) {
      ref.read(mapCenterProvider.notifier).state = LatLng(result.latitude!, result.longitude!);
    } else {
      ref.read(mapCenterProvider.notifier).state = _defaultCenter;
      setState(() => _locationNotice = result.message);
    }
    setState(() => _resolvingLocation = false);
  }

  void _showPropertyPreview(Property property) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              InkWell(
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.push(AppRoutes.propertyDetailPath(property.id));
                },
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: PropertyImage(
                        property.coverImage,
                        width: 105,
                        height: 105,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              StatusBadge.category(property.type.label),
                              IconButton(
                                icon: Icon(
                                  property.isFavorite
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  color: property.isFavorite
                                      ? AppColors.danger
                                      : AppColors.textSecondary,
                                  size: 20,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () async {
                                  try {
                                    await toggleFavorite(ref, property.id);
                                  } catch (e) {
                                    if (sheetContext.mounted) {
                                      showErrorSnackbar(sheetContext, e);
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            property.title,
                            style: AppTextStyles.h3.copyWith(fontSize: 15),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                size: 14,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(
                                  property.locationLabel,
                                  style: AppTextStyles.caption,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            Formatters.price(property.price),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final center = ref.watch(mapCenterProvider) ?? _defaultCenter;
    final radius = ref.watch(mapRadiusKmProvider);
    final nearbyAsync = ref.watch(nearbyPropertiesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Carte des annonces')),
      body: _resolvingLocation
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                AppMapView(
                  center: center,
                  mapController: _mapController,
                  zoom: 13,
                  markers: nearbyAsync.maybeWhen(
                    data: (properties) => [
                      for (final property in properties)
                        if (property.latitude != null && property.longitude != null)
                          AppMapMarker(
                            id: property.id,
                            latitude: property.latitude!,
                            longitude: property.longitude!,
                            onTap: () => _showPropertyPreview(property),
                          ),
                    ],
                    orElse: () => const [],
                  ),
                ),
                Positioned(
                  top: AppSpacing.md,
                  left: AppSpacing.screenPadding,
                  right: AppSpacing.screenPadding,
                  child: _RadiusSelector(
                    selected: radius,
                    onChanged: (value) =>
                        ref.read(mapRadiusKmProvider.notifier).state = value,
                  ),
                ),
                if (nearbyAsync.isLoading)
                  const Positioned(
                    top: 70,
                    right: AppSpacing.md,
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  ),
                if (_locationNotice != null)
                  Positioned(
                    bottom: AppSpacing.md,
                    left: AppSpacing.screenPadding,
                    right: AppSpacing.screenPadding,
                    child: _InfoBanner(message: _locationNotice!),
                  ),
              ],
            ),
    );
  }
}

class _RadiusSelector extends StatelessWidget {
  const _RadiusSelector({required this.selected, required this.onChanged});

  final double selected;
  final void Function(double) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (final radiusKm in _radiusOptionsKm)
            _RadiusChip(
              label: radiusKm == 0 ? 'Toutes' : '${radiusKm.toInt()} km',
              isSelected: selected == radiusKm,
              onTap: () => onChanged(radiusKm),
            ),
        ],
      ),
    );
  }
}

class _RadiusChip extends StatelessWidget {
  const _RadiusChip({required this.label, required this.isSelected, required this.onTap});

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? AppColors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Text(message, style: AppTextStyles.caption, textAlign: TextAlign.center),
    );
  }
}
