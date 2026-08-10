import 'package:equatable/equatable.dart';
import '../../properties/models/property_enums.dart';

/// Paramètres de filtre/recherche, reconstruits immutablement à chaque
/// changement (copyWith) pour piloter le provider [filterParamsProvider].
class FilterParams extends Equatable {
  final TransactionType transactionType;
  final String commune;
  final String district;
  final bool isFuture;
  final PropertyType propertyType;
  final String? category;
  final double? budgetMin;
  final double? budgetMax;

  const FilterParams({
    this.transactionType = TransactionType.location,
    this.commune = '',
    this.district = '',
    this.isFuture = false,
    this.propertyType = PropertyType.logement,
    this.category,
    this.budgetMin,
    this.budgetMax,
  });

  FilterParams copyWith({
    TransactionType? transactionType,
    String? commune,
    String? district,
    bool? isFuture,
    PropertyType? propertyType,
    String? category,
    double? budgetMin,
    double? budgetMax,
  }) {
    return FilterParams(
      transactionType: transactionType ?? this.transactionType,
      commune: commune ?? this.commune,
      district: district ?? this.district,
      isFuture: isFuture ?? this.isFuture,
      propertyType: propertyType ?? this.propertyType,
      category: category ?? this.category,
      budgetMin: budgetMin ?? this.budgetMin,
      budgetMax: budgetMax ?? this.budgetMax,
    );
  }

  @override
  List<Object?> get props => [
        transactionType,
        commune,
        district,
        isFuture,
        propertyType,
        category,
        budgetMin,
        budgetMax,
      ];
}
