import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/filter_params.dart';

/// Brouillon des filtres, modifié en direct pendant que le bottom sheet est ouvert.
final draftFilterParamsProvider =
    StateProvider.autoDispose<FilterParams>((ref) => const FilterParams());

/// Filtres réellement appliqués à la recherche (null = aucun filtre avancé).
final appliedFilterParamsProvider = StateProvider<FilterParams?>((ref) => null);
