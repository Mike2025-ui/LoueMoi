import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/env.dart';
import '../../../core/network/network_providers.dart';
import '../../auth/providers/auth_providers.dart';
import '../../filters/models/filter_params.dart';
import '../../filters/providers/filter_providers.dart';
import '../data/api_property_repository.dart';
import '../data/property_repository.dart';
import '../models/property.dart';
import '../models/property_enums.dart';

final propertyRepositoryProvider = Provider<PropertyRepository>((ref) {
  if (Env.useMockData) return MockPropertyRepository();
  return ApiPropertyRepository(ref.watch(apiClientProvider));
});

/// Onglet Location/Vente sélectionné sur l'écran Menu (indépendant des filtres avancés).
final homeTransactionTypeProvider =
    StateProvider<TransactionType>((ref) => TransactionType.location);

final searchQueryProvider = StateProvider<String>((ref) => '');

/// Cache des propriétés chargées sur l'écran d'accueil, réutilisé par le détail
/// pour suggérer des biens similaires sans déclencher d'appel réseau redondant.
final homePropertiesCacheProvider = StateProvider<List<Property>>((ref) => const []);

FilterParams _effectiveFilters(Ref ref) {
  final transactionType = ref.watch(homeTransactionTypeProvider);
  final appliedFilters = ref.watch(appliedFilterParamsProvider);
  return (appliedFilters ?? const FilterParams()).copyWith(transactionType: transactionType);
}

/// Pagine `/api/properties/` (scroll infini) : conserve les pages déjà
/// chargées et en ajoute une nouvelle via [loadNextPage]. Recréé
/// automatiquement quand l'onglet Location/Vente ou les filtres changent.
class PropertiesController extends StateNotifier<AsyncValue<List<Property>>> {
  PropertiesController(this._repository, this._filters) : super(const AsyncValue.loading()) {
    _loadFirstPage();
  }

  final PropertyRepository _repository;
  final FilterParams _filters;

  int _page = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;

  Future<void> _loadFirstPage() async {
    state = const AsyncValue.loading();
    try {
      final page = await _repository.fetchProperties(filters: _filters, page: 1);
      _page = 1;
      _hasMore = page.hasMore;
      state = AsyncValue.data(page.results);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Charge la page suivante et l'ajoute à la liste courante. Sans effet si
  /// une page est déjà en cours de chargement ou s'il n'y a plus de résultats.
  Future<void> loadNextPage() async {
    final current = state.valueOrNull;
    if (_isLoadingMore || !_hasMore || current == null) return;

    _isLoadingMore = true;
    try {
      final nextPage = await _repository.fetchProperties(filters: _filters, page: _page + 1);
      _page += 1;
      _hasMore = nextPage.hasMore;
      state = AsyncValue.data([...current, ...nextPage.results]);
    } catch (_) {
      // Erreur non bloquante : l'utilisateur peut re-scroller pour réessayer,
      // la liste déjà chargée reste affichée.
    } finally {
      _isLoadingMore = false;
    }
  }

  /// Bascule l'état favori localement (UI optimiste), sans refetch réseau.
  void applyFavoriteChange(String propertyId, bool isFavorite) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data([
      for (final property in current)
        if (property.id == propertyId) property.copyWith(isFavorite: isFavorite) else property,
    ]);
  }

  Future<void> refresh() => _loadFirstPage();
}

final propertiesControllerProvider = StateNotifierProvider.autoDispose<PropertiesController,
    AsyncValue<List<Property>>>((ref) {
  final repository = ref.watch(propertyRepositoryProvider);
  final filters = _effectiveFilters(ref);
  return PropertiesController(repository, filters);
});

/// Liste affichée à l'écran : la pagination de [propertiesControllerProvider],
/// filtrée côté client par la recherche texte libre.
final propertiesListProvider = Provider.autoDispose<AsyncValue<List<Property>>>((ref) {
  final controllerState = ref.watch(propertiesControllerProvider);
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();

  return controllerState.whenData(
    (list) => list
        .where((p) => p.status != PropertyStatus.accomplie)
        .where((p) =>
            query.isEmpty ||
            p.title.toLowerCase().contains(query) ||
            p.commune.toLowerCase().contains(query) ||
            p.district.toLowerCase().contains(query))
        .toList(),
  );
});

final propertyByIdProvider =
    FutureProvider.family<Property, String>((ref, id) async {
  final repository = ref.watch(propertyRepositoryProvider);
  return repository.fetchPropertyById(id);
});

final favoritesListProvider = FutureProvider<List<Property>>((ref) async {
  final user = ref.watch(authControllerProvider).valueOrNull;
  if (user == null && !Env.useMockData) return const [];
  final repository = ref.watch(propertyRepositoryProvider);
  final list = await repository.fetchFavorites();
  return list.where((p) => p.status != PropertyStatus.accomplie).toList();
});

/// Annonces publiques d'un propriétaire donné — "Rechercher un
/// propriétaire" côté agent (voir features/bailleurs).
final propertiesByOwnerProvider =
    FutureProvider.autoDispose.family<List<Property>, String>((ref, ownerId) async {
  final repository = ref.watch(propertyRepositoryProvider);
  return repository.fetchPropertiesByOwner(ownerId);
});

/// Annonces de l'utilisateur connecté ("Mes annonces" / "Mes biens") —
/// filtrage 100% côté Django, jamais recalculé côté Flutter. Réutilisé tel
/// quel par MyPropertiesScreen pour l'agent ET le bailleur (deux rôles
/// indépendants, chacun avec son propre endpoint /api/agent/properties/ ou
/// /api/bailleur/properties/) — un seul écran, un seul provider.
final myPropertiesProvider = FutureProvider.autoDispose<List<Property>>((ref) async {
  final repository = ref.watch(propertyRepositoryProvider);
  final user = ref.watch(authControllerProvider).valueOrNull;
  final List<Property> list;
  if (user?.isBailleur ?? false) {
    list = await repository.fetchMyPropertiesAsBailleur();
  } else {
    list = await repository.fetchMyProperties();
  }
  return list.where((p) => p.status != PropertyStatus.accomplie).toList();
});

/// Bascule l'état favori en optimiste sur la liste Menu (l'UI change
/// immédiatement si la propriété y est affichée), puis confirme côté
/// serveur ; en cas d'échec, l'état est restauré. Le Détail et les Favoris
/// se resynchronisent via invalidate (source de vérité : la réponse serveur).
/// "Marquer occupé" / "Marquer disponible" depuis la carte de réservation —
/// réservé au propriétaire du bien côté Django (403 sinon, voir
/// IsPropertyOwnerOrReadOnly). Invalide propertyByIdProvider, seule source
/// affichée par ReservationCard : pas de mise à jour optimiste ici, l'action
/// est rare et la confirmation serveur est immédiate.
Future<void> markPropertyStatus(
  WidgetRef ref, {
  required String propertyId,
  required PropertyStatus status,
}) async {
  final repository = ref.read(propertyRepositoryProvider);
  await repository.updatePropertyStatus(propertyId, status);
  ref.invalidate(propertyByIdProvider(propertyId));
}

Future<void> toggleFavorite(WidgetRef ref, String propertyId) async {
  final controller = ref.read(propertiesControllerProvider.notifier);
  final currentList = ref.read(propertiesControllerProvider).valueOrNull ?? const [];

  bool wasFavorite = false;
  for (final property in currentList) {
    if (property.id == propertyId) {
      wasFavorite = property.isFavorite;
      break;
    }
  }

  controller.applyFavoriteChange(propertyId, !wasFavorite);
  try {
    final repository = ref.read(propertyRepositoryProvider);
    await repository.toggleFavorite(propertyId);
    ref.invalidate(favoritesListProvider);
    ref.invalidate(propertyByIdProvider(propertyId));
  } catch (e) {
    controller.applyFavoriteChange(propertyId, wasFavorite);
    rethrow;
  }
}
