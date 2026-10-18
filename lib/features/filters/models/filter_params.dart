import 'package:equatable/equatable.dart';
import '../../properties/models/property_enums.dart';

/// Paramètres de filtre/recherche, reconstruits immutablement à chaque
/// changement (copyWith) pour piloter le provider [filterParamsProvider].
class FilterParams extends Equatable {
  final TransactionType transactionType;
  final String commune;
  final String district;
  final bool isFuture;
  final PropertyType? propertyType;
  final String? category;
  final double? budgetMin;
  final double? budgetMax;

  const FilterParams({
    this.transactionType = TransactionType.location,
    this.commune = '',
    this.district = '',
    this.isFuture = false,
    this.propertyType,
    this.category,
    this.budgetMin,
    this.budgetMax,
  });

  /// Indique si au moins un filtre avancé (autre que le toggle de base
  /// Location/Vente) est actuellement actif.
  bool get hasActiveAdvancedFilters {
    return commune.trim().isNotEmpty ||
        district.trim().isNotEmpty ||
        isFuture ||
        propertyType != null ||
        (category != null && category!.isNotEmpty) ||
        budgetMin != null ||
        budgetMax != null;
  }

  FilterParams copyWith({
    TransactionType? transactionType,
    String? commune,
    String? district,
    bool? isFuture,
    PropertyType? propertyType,
    String? category,
    double? budgetMin,
    double? budgetMax,
    bool clearPropertyType = false,
    bool clearCategory = false,
    bool clearBudgetMin = false,
    bool clearBudgetMax = false,
  }) {
    return FilterParams(
      transactionType: transactionType ?? this.transactionType,
      commune: commune ?? this.commune,
      district: district ?? this.district,
      isFuture: isFuture ?? this.isFuture,
      propertyType: clearPropertyType ? null : (propertyType ?? this.propertyType),
      category: clearCategory ? null : (category ?? this.category),
      budgetMin: clearBudgetMin ? null : (budgetMin ?? this.budgetMin),
      budgetMax: clearBudgetMax ? null : (budgetMax ?? this.budgetMax),
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
