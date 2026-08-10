import 'property.dart';

/// Une page de résultats de propriétés (pagination Django : count/next/results).
class PropertyPage {
  const PropertyPage({required this.results, required this.hasMore, required this.count});

  final List<Property> results;
  final bool hasMore;
  final int count;
}
