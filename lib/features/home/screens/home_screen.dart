import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/routes.dart';
import '../../../core/services/ota_and_remote_config_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/feedback.dart';
import '../../../core/widgets/app_logo.dart';
import '../../auth/providers/auth_providers.dart';
import '../../filters/models/filter_params.dart';
import '../../filters/providers/filter_providers.dart';
import '../../filters/screens/filters_sheet.dart';
import '../../notifications/providers/notification_providers.dart';
import '../../properties/models/property.dart';
import '../../properties/models/property_enums.dart';
import '../../properties/providers/property_providers.dart';
import '../../properties/widgets/property_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Scroll infini : charge la page suivante un peu avant d'atteindre le bas
  /// de la grille, sans aucun indicateur visuel supplémentaire (les nouvelles
  /// cartes apparaissent simplement au fil du scroll).
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 400) {
      ref.read(propertiesControllerProvider.notifier).loadNextPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<List<Property>>>(propertiesListProvider, (_, next) {
      next.whenData((list) {
        ref.read(homePropertiesCacheProvider.notifier).state = list;
      });
    });

    ref.listen<String>(searchQueryProvider, (_, next) {
      if (_searchController.text != next) {
        _searchController.text = next;
      }
    });

    final transactionType = ref.watch(homeTransactionTypeProvider);
    final propertiesAsync = ref.watch(propertiesListProvider);
    final appliedFilters = ref.watch(appliedFilterParamsProvider);
    final searchQuery = ref.watch(searchQueryProvider);
    final unreadCount =
        ref.watch(unreadNotificationsCountProvider).valueOrNull ?? 0;
    final remoteConfig = ref.watch(remoteAppConfigProvider).valueOrNull;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktopWeb = screenWidth >= 768;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            if (remoteConfig != null &&
                remoteConfig.announcementEnabled &&
                (remoteConfig.announcementTitle.isNotEmpty ||
                    remoteConfig.announcementBody.isNotEmpty))
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding,
                  AppSpacing.sm,
                  AppSpacing.screenPadding,
                  0,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.campaign_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (remoteConfig.announcementTitle.isNotEmpty)
                            Text(
                              remoteConfig.announcementTitle,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: AppColors.primary,
                              ),
                            ),
                          if (remoteConfig.announcementBody.isNotEmpty)
                            Text(
                              remoteConfig.announcementBody,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textPrimary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (!isDesktopWeb)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding,
                  AppSpacing.md,
                  AppSpacing.screenPadding,
                  0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const AppLogo(),
                    InkWell(
                      onTap: () => context.go(AppRoutes.notifications),
                      borderRadius: BorderRadius.circular(20),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Icon(
                              Icons.notifications_none,
                              size: 20,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (unreadCount > 0)
                            Positioned(
                              top: -2,
                              right: -2,
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: AppColors.danger,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                child: Text(
                                  '$unreadCount',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppColors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding,
                  AppSpacing.md,
                  AppSpacing.screenPadding,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Explorez les biens disponibles',
                      style: TextStyle(
                        fontSize: isDesktopWeb ? 20 : 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Location et vente de logements vérifiés en Côte d’Ivoire',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.md),
                  // Toggle Location / Vente (compact sur Web)
                  SizedBox(
                    width: isDesktopWeb ? 260 : double.infinity,
                    child: Row(
                      children: [
                        Expanded(
                          child: _TransactionToggleButton(
                            label: 'Location',
                            isActive: transactionType == TransactionType.location,
                            isCompact: isDesktopWeb,
                            onTap: () {
                              ref.read(homeTransactionTypeProvider.notifier).state =
                                  TransactionType.location;
                              final applied = ref.read(appliedFilterParamsProvider);
                              if (applied != null && (applied.budgetMin != null || applied.budgetMax != null)) {
                                ref.read(appliedFilterParamsProvider.notifier).state =
                                    applied.copyWith(clearBudgetMin: true, clearBudgetMax: true);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _TransactionToggleButton(
                            label: 'Vente',
                            isActive: transactionType == TransactionType.vente,
                            isCompact: isDesktopWeb,
                            onTap: () {
                              ref.read(homeTransactionTypeProvider.notifier).state =
                                  TransactionType.vente;
                              final applied = ref.read(appliedFilterParamsProvider);
                              if (applied != null && (applied.budgetMin != null || applied.budgetMax != null)) {
                                ref.read(appliedFilterParamsProvider.notifier).state =
                                    applied.copyWith(clearBudgetMin: true, clearBudgetMax: true);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // Barre de recherche et filtres (largeur ergonomique sur Web)
                  SizedBox(
                    width: isDesktopWeb ? 680 : double.infinity,
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: isDesktopWeb ? 42 : 48,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.search,
                                  size: 19,
                                  color: AppColors.textHint,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    onChanged: (v) =>
                                        ref.read(searchQueryProvider.notifier).state =
                                            v,
                                    decoration: const InputDecoration(
                                      hintText: 'Recherche...',
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      errorBorder: InputBorder.none,
                                      disabledBorder: InputBorder.none,
                                      contentPadding: EdgeInsets.zero,
                                      isDense: true,
                                    ),
                                  ),
                                ),
                                if (searchQuery.isNotEmpty)
                                  InkWell(
                                    onTap: () {
                                      _searchController.clear();
                                      ref.read(searchQueryProvider.notifier).state = '';
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.all(4),
                                      child: Icon(
                                        Icons.close,
                                        size: 18,
                                        color: AppColors.textHint,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        InkWell(
                          onTap: () => showFiltersSheet(context, ref),
                          child: Container(
                            width: isDesktopWeb ? 42 : 48,
                            height: isDesktopWeb ? 42 : 48,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                              border: Border.all(
                                color: appliedFilters != null ? AppColors.primary : AppColors.border,
                                width: appliedFilters != null ? 1.5 : 1.0,
                              ),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Icon(
                                  Icons.tune,
                                  size: 19,
                                  color: appliedFilters != null ? AppColors.primary : AppColors.textPrimary,
                                ),
                                if (appliedFilters != null)
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Container(
                                      width: 7,
                                      height: 7,
                                      decoration: const BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        InkWell(
                          onTap: () => context.push(AppRoutes.propertyMap),
                          child: Container(
                            width: isDesktopWeb ? 42 : 48,
                            height: isDesktopWeb ? 42 : 48,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(AppRadius.pill),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Icon(
                              Icons.map_outlined,
                              size: 19,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(
                    width: isDesktopWeb ? 720 : double.infinity,
                    child: const _BudgetQuickChips(),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () async {
                  await ref
                      .read(propertiesControllerProvider.notifier)
                      .refresh();
                },
                child: propertiesAsync.when(
                  data: (properties) {
                    if (properties.isEmpty) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          const SizedBox(height: 80),
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.search_off_outlined,
                                    size: 56,
                                    color: AppColors.textHint,
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  const Text(
                                    'Aucune propriété trouvée',
                                    style: AppTextStyles.h3,
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  const Text(
                                    'Modifiez vos critères ou appuyez sur Menu ci-dessous pour tout réinitialiser.',
                                    style: AppTextStyles.caption,
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      ref.read(appliedFilterParamsProvider.notifier).state = null;
                                      ref.read(searchQueryProvider.notifier).state = '';
                                      _searchController.clear();
                                      ref.read(propertiesControllerProvider.notifier).refresh();
                                    },
                                    icon: const Icon(Icons.refresh, size: 18),
                                    label: const Text('Réinitialiser les filtres'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      foregroundColor: AppColors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 12,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(AppRadius.pill),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                    final screenWidth = MediaQuery.of(context).size.width;
                    final sidebarWidth = screenWidth < 1024 ? 220.0 : 240.0;
                    final availableWidth = screenWidth >= 768 ? (screenWidth - sidebarWidth) : screenWidth;
                    final int crossAxisCount;
                    final double childAspectRatio;
                    if (availableWidth >= 1280) {
                      crossAxisCount = 4;
                      childAspectRatio = 0.74;
                    } else if (availableWidth >= 880) {
                      crossAxisCount = 3;
                      childAspectRatio = 0.72;
                    } else if (availableWidth >= 520) {
                      crossAxisCount = 2;
                      childAspectRatio = 0.70;
                    } else {
                      crossAxisCount = 2;
                      childAspectRatio = 0.68;
                    }

                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1240),
                        child: GridView.builder(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.screenPadding,
                            AppSpacing.sm,
                            AppSpacing.screenPadding,
                            100,
                          ),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: AppSpacing.md,
                                mainAxisSpacing: AppSpacing.lg,
                                childAspectRatio: childAspectRatio,
                              ),
                          itemCount: properties.length,
                          itemBuilder: (context, index) {
                            final property = properties[index];
                            return PropertyCard(
                              property: property,
                              onTap: () => context.push(
                                AppRoutes.propertyDetailPath(property.id),
                              ),
                              onFavoriteTap: () async {
                                final user = ref.read(authControllerProvider).valueOrNull;
                                if (user == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text('Veuillez vous connecter pour gérer vos favoris.'),
                                      backgroundColor: AppColors.primary,
                                      action: SnackBarAction(
                                        label: 'Se connecter',
                                        textColor: AppColors.white,
                                        onPressed: () => context.push(AppRoutes.login),
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                try {
                                  await toggleFavorite(ref, property.id);
                                } catch (e) {
                                  if (context.mounted) {
                                    showErrorSnackbar(context, e);
                                  }
                                }
                              },
                            );
                          },
                        ),
                      ),
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 120),
                      Center(
                        child: Text(
                          'Impossible de charger les annonces. Glissez vers le bas pour actualiser.',
                          style: AppTextStyles.caption,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionToggleButton extends StatelessWidget {
  const _TransactionToggleButton({
    required this.label,
    required this.isActive,
    required this.onTap,
    this.isCompact = false,
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        height: isCompact ? 36 : AppSizes.buttonHeight,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: isActive ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: isCompact ? 13 : 16,
            fontWeight: FontWeight.w600,
            color: isActive ? AppColors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _BudgetQuickChips extends ConsumerWidget {
  const _BudgetQuickChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionType = ref.watch(homeTransactionTypeProvider);
    final appliedFilters = ref.watch(appliedFilterParamsProvider);
    final isLocation = transactionType == TransactionType.location;

    final List<(String, double?, double?)> options = isLocation
        ? [
            ('Tous', null, null),
            ('< 100k', null, 100000),
            ('100k - 250k', 100000, 250000),
            ('250k - 500k', 250000, 500000),
            ('> 500k', 500000, null),
          ]
        : [
            ('Tous', null, null),
            ('< 20M', null, 20000000),
            ('20M - 50M', 20000000, 50000000),
            ('50M - 100M', 50000000, 100000000),
            ('> 100M', 100000000, null),
          ];

    final currentMin = appliedFilters?.budgetMin;
    final currentMax = appliedFilters?.budgetMax;

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPadding,
        ),
        itemCount: options.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: AppSpacing.xs),
        itemBuilder: (context, index) {
          final (label, min, max) = options[index];
          final isSelected = (min == null && max == null)
              ? (currentMin == null && currentMax == null)
              : (currentMin == min && currentMax == max);

          return FilterChip(
            label: Text(label),
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected ? AppColors.white : AppColors.textPrimary,
            ),
            selected: isSelected,
            showCheckmark: false,
            selectedColor: AppColors.primary,
            backgroundColor: AppColors.surfaceMuted,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              side: BorderSide(
                color: isSelected ? AppColors.primary : AppColors.border,
              ),
            ),
            onSelected: (_) {
              HapticFeedback.lightImpact();
              if (min == null && max == null) {
                // "Tous"
                if (appliedFilters != null) {
                  ref
                      .read(appliedFilterParamsProvider.notifier)
                      .state = FilterParams(
                    transactionType: appliedFilters.transactionType,
                    commune: appliedFilters.commune,
                    district: appliedFilters.district,
                    isFuture: appliedFilters.isFuture,
                    propertyType: appliedFilters.propertyType,
                    category: appliedFilters.category,
                    budgetMin: null,
                    budgetMax: null,
                  );
                }
              } else if (isSelected) {
                // Deselect
                ref
                    .read(appliedFilterParamsProvider.notifier)
                    .state = FilterParams(
                  transactionType:
                      appliedFilters?.transactionType ?? transactionType,
                  commune: appliedFilters?.commune ?? '',
                  district: appliedFilters?.district ?? '',
                  isFuture: appliedFilters?.isFuture ?? false,
                  propertyType:
                      appliedFilters?.propertyType ?? PropertyType.logement,
                  category: appliedFilters?.category,
                  budgetMin: null,
                  budgetMax: null,
                );
              } else {
                ref
                    .read(appliedFilterParamsProvider.notifier)
                    .state = FilterParams(
                  transactionType:
                      appliedFilters?.transactionType ?? transactionType,
                  commune: appliedFilters?.commune ?? '',
                  district: appliedFilters?.district ?? '',
                  isFuture: appliedFilters?.isFuture ?? false,
                  propertyType:
                      appliedFilters?.propertyType ?? PropertyType.logement,
                  category: appliedFilters?.category,
                  budgetMin: min,
                  budgetMax: max,
                );
              }
            },
          );
        },
      ),
    );
  }
}
