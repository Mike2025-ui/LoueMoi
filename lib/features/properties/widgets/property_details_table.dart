import 'package:flutter/material.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../models/property.dart';

/// Tableau "Type / Details / Equipements / Localisation" affiché sous
/// "Configuration" dans le détail et le résumé de réservation.
class PropertyDetailsTable extends StatelessWidget {
  const PropertyDetailsTable({super.key, required this.property});

  final Property property;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Row(label: 'Type', value: property.category),
        _Row(label: 'Details', value: property.features.join(',')),
        _Row(label: 'Equipements', value: property.amenities.join(',')),
        _Row(label: 'Localisation', value: property.locationLabel),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: AppTextStyles.caption),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTextStyles.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
