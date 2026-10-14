import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../properties/providers/property_providers.dart';
import '../models/filter_params.dart';

/// Brouillon des filtres, modifié en direct pendant que le bottom sheet est
/// ouvert. La valeur initiale est dérivée ici (ref.read, une seule fois à la
/// création — jamais ref.watch, pour ne pas réinitialiser le brouillon en
/// cours de saisie si homeTransactionTypeProvider changeait) des filtres
/// déjà appliqués + du toggle Location/Vente de HomeScreen, plutôt que
/// d'être réécrite depuis FiltersSheet.initState(). Muter un provider
/// pendant initState() (donc pendant que l'arbre de widgets est en
/// construction) provoque "Tried to modify a provider while the widget
/// tree was building" — l'erreur reproduite sur téléphone.
final draftFilterParamsProvider = StateProvider.autoDispose<FilterParams>((ref) {
  final applied = ref.read(appliedFilterParamsProvider);
  final transactionType = ref.read(homeTransactionTypeProvider);
  return (applied ?? const FilterParams()).copyWith(transactionType: transactionType);
});

/// Filtres réellement appliqués à la recherche (null = aucun filtre avancé).
final appliedFilterParamsProvider = StateProvider<FilterParams?>((ref) => null);
