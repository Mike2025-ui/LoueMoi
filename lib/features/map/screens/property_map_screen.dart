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
import '../../../core/widgets/app_map_view.dart';
import '../../properties/models/property.dart';
import '../../properties/providers/property_providers.dart';
import '../../properties/widgets/property_card.dart';
import '../providers/map_providers.dart';

const List<double> _radiusOptionsKm = [1, 5, 10, 20];

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
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: SizedBox(
          height: 260,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 170,
              child: PropertyCard(
                property: property,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  context.push(AppRoutes.propertyDetailPath(property.id));
                },
                onFavoriteTap: () async {
                  try {
                    await toggleFavorite(ref, property.id);
                  } catch (e) {
                    if (sheetContext.mounted) showErrorSnackbar(sheetContext, e);
                  }
                },
              ),
            ),
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
              label: '${radiusKm.toInt()} km',
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
