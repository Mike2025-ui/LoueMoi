import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../config/env.dart';
import '../theme/app_colors.dart';

/// Un marqueur affiché sur [AppMapView].
class AppMapMarker {
  const AppMapMarker({
    required this.id,
    required this.latitude,
    required this.longitude,
    this.onTap,
  });

  final String id;
  final double latitude;
  final double longitude;
  final VoidCallback? onTap;
}

/// Abstraction au-dessus de flutter_map/OpenStreetMap : c'est le seul
/// fichier du projet qui connaît le fournisseur de tuiles. Publier, Détail
/// et PropertyMapScreen ne manipulent que [AppMapView]/[AppMapMarker] — un
/// changement de fournisseur de carte plus tard ne touche que ce fichier.
class AppMapView extends StatelessWidget {
  const AppMapView({
    super.key,
    required this.center,
    this.zoom = 14,
    this.markers = const [],
    this.interactive = true,
    this.onTap,
    this.mapController,
  });

  final LatLng center;
  final double zoom;
  final List<AppMapMarker> markers;

  /// false pour une carte en lecture seule (PropertyDetail) : pas de
  /// pan/zoom tactile.
  final bool interactive;

  final void Function(LatLng position)? onTap;
  final MapController? mapController;

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: zoom,
        interactionOptions: InteractionOptions(
          flags: interactive ? InteractiveFlag.all : InteractiveFlag.none,
        ),
        onTap: onTap == null ? null : (_, point) => onTap!(point),
      ),
      children: [
        TileLayer(
          urlTemplate: Env.mapTileUrlTemplate,
          userAgentPackageName: 'com.louemoi.app',
        ),
        MarkerLayer(
          markers: [
            for (final marker in markers)
              Marker(
                point: LatLng(marker.latitude, marker.longitude),
                width: 36,
                height: 36,
                child: GestureDetector(
                  onTap: marker.onTap,
                  child: const Icon(
                    Icons.location_on,
                    color: AppColors.primary,
                    size: 36,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
