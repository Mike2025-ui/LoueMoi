import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/feedback.dart';
import '../../../core/widgets/app_logo.dart';
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

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
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

    final transactionType = ref.watch(homeTransactionTypeProvider);
    final propertiesAsync = ref.watch(propertiesListProvider);
    final unreadCount =
        ref.watch(unreadNotificationsCountProvider).valueOrNull ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
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
                    onTap: () => context.push(AppRoutes.notifications),
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
            ),
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _TransactionToggleButton(
                      label: 'Location',
                      isActive: transactionType == TransactionType.location,
                      onTap: () =>
                          ref.read(homeTransactionTypeProvider.notifier).state =
                              TransactionType.location,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: _TransactionToggleButton(
                      label: 'Vente',
                      isActive: transactionType == TransactionType.vente,
                      onTap: () =>
                          ref.read(homeTransactionTypeProvider.notifier).state =
                              TransactionType.vente,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
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
                            size: 20,
                            color: AppColors.textHint,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: TextField(
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
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  InkWell(
                    onTap: () => showFiltersSheet(context, ref),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(
                        Icons.tune,
                        size: 20,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  InkWell(
                    onTap: () => context.push(AppRoutes.propertyMap),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(
                        Icons.map_outlined,
                        size: 20,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const _BudgetQuickChips(),
            const SizedBox(height: AppSpacing.xs),
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
                        children: const [
                          SizedBox(height: 120),
                          Center(
                            child: Text(
                              'Aucune propriété trouvée',
                              style: AppTextStyles.caption,
                            ),
                          ),
                        ],
                      );
                    }
                    return GridView.builder(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screenPadding,
                        0,
                        AppSpacing.screenPadding,
                        100,
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: AppSpacing.md,
                            mainAxisSpacing: AppSpacing.lg,
                            childAspectRatio: 0.68,
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
  });

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        height: AppSizes.buttonHeight,
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
            fontSize: 16,
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
