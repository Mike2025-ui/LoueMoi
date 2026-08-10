import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/section_divider_title.dart';
import '../../properties/models/property_enums.dart';
import '../providers/filter_providers.dart';
import '../widgets/filter_toggle_chip.dart';

Future<void> showFiltersSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (_) => const FiltersSheet(),
  );
}

class FiltersSheet extends ConsumerStatefulWidget {
  const FiltersSheet({super.key});

  @override
  ConsumerState<FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends ConsumerState<FiltersSheet> {
  final _communeController = TextEditingController();
  final _quartierController = TextEditingController();
  final _budgetMinController = TextEditingController();
  final _budgetMaxController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final applied = ref.read(appliedFilterParamsProvider);
    if (applied != null) {
      ref.read(draftFilterParamsProvider.notifier).state = applied;
      _communeController.text = applied.commune;
      _quartierController.text = applied.district;
      _budgetMinController.text = applied.budgetMin?.toStringAsFixed(0) ?? '';
      _budgetMaxController.text = applied.budgetMax?.toStringAsFixed(0) ?? '';
    }
  }

  @override
  void dispose() {
    _communeController.dispose();
    _quartierController.dispose();
    _budgetMinController.dispose();
    _budgetMaxController.dispose();
    super.dispose();
  }

  void _selectPropertyType(PropertyType type) {
    final draft = ref.read(draftFilterParamsProvider);
    String? category;
    switch (type) {
      case PropertyType.logement:
        category = AppConstants.logementCategories.first;
        break;
      case PropertyType.terrain:
        category = 'Terrain';
        break;
      case PropertyType.magasin:
        category = 'Magasin';
        break;
    }
    ref.read(draftFilterParamsProvider.notifier).state =
        draft.copyWith(propertyType: type, category: category);
  }

  void _search() {
    final draft = ref.read(draftFilterParamsProvider);
    final updated = draft.copyWith(
      budgetMin: double.tryParse(_budgetMinController.text),
      budgetMax: double.tryParse(_budgetMaxController.text),
    );
    ref.read(appliedFilterParamsProvider.notifier).state = updated;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(draftFilterParamsProvider);
    final notifier = ref.read(draftFilterParamsProvider.notifier);

    return DraggableScrollableSheet(
      initialChildSize: 0.94,
      maxChildSize: 0.96,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(Icons.close, size: 22),
                  ),
                  const Expanded(
                    child: Text(
                      'Filtres',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.h3,
                    ),
                  ),
                  const SizedBox(width: 22),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                          Row(
                            children: [
                              FilterToggleChip(
                                label: 'Location',
                                isActive:
                                    draft.transactionType == TransactionType.location,
                                onTap: () => notifier.state = draft.copyWith(
                                  transactionType: TransactionType.location,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              FilterToggleChip(
                                label: 'Vente',
                                isActive: draft.transactionType == TransactionType.vente,
                                onTap: () => notifier.state = draft.copyWith(
                                  transactionType: TransactionType.vente,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Commune', style: AppTextStyles.label),
                              if (draft.propertyType == PropertyType.logement)
                                Row(
                                  children: [
                                    Checkbox(
                                      value: draft.isFuture,
                                      activeColor: AppColors.primary,
                                      onChanged: (v) =>
                                          notifier.state = draft.copyWith(isFuture: v),
                                    ),
                                    const Text('Bien futur', style: AppTextStyles.caption),
                                  ],
                                ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          AppTextField(
                            hint: 'Commune',
                            controller: _communeController,
                            onChanged: (v) =>
                                notifier.state = draft.copyWith(commune: v),
                            suffixIcon:
                                const Icon(Icons.my_location, color: AppColors.textHint),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          const Text('Quartier', style: AppTextStyles.label),
                          const SizedBox(height: AppSpacing.sm),
                          AppTextField(
                            hint: 'Quartier',
                            controller: _quartierController,
                            onChanged: (v) =>
                                notifier.state = draft.copyWith(district: v),
                            suffixIcon:
                                const Icon(Icons.my_location, color: AppColors.textHint),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                      ),
                    ),
                    const SectionTitle(title: 'Type de bien'),
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
                          Row(
                            children: [
                              FilterToggleChip(
                                label: 'Logement',
                                isActive: draft.propertyType == PropertyType.logement,
                                onTap: () => _selectPropertyType(PropertyType.logement),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              FilterToggleChip(
                                label: 'Terrain',
                                isActive: draft.propertyType == PropertyType.terrain,
                                onTap: () => _selectPropertyType(PropertyType.terrain),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              FilterToggleChip(
                                label: 'Magasin',
                                isActive: draft.propertyType == PropertyType.magasin,
                                onTap: () => _selectPropertyType(PropertyType.magasin),
                              ),
                            ],
                          ),
                          if (draft.propertyType == PropertyType.logement) ...[
                            const SizedBox(height: AppSpacing.md),
                            Wrap(
                              spacing: AppSpacing.sm,
                              runSpacing: AppSpacing.sm,
                              children: AppConstants.logementCategories.map((c) {
                                return FilterToggleChip(
                                  label: c,
                                  isActive: draft.category == c,
                                  expanded: false,
                                  onTap: () =>
                                      notifier.state = draft.copyWith(category: c),
                                );
                              }).toList(),
                            ),
                          ],
                          const SizedBox(height: AppSpacing.lg),
                        ],
                      ),
                    ),
                    const SectionTitle(title: 'Plage budgetaire'),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screenPadding,
                        AppSpacing.md,
                        AppSpacing.screenPadding,
                        AppSpacing.lg,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Minimum', style: AppTextStyles.label),
                          const SizedBox(height: AppSpacing.sm),
                          AppTextField(
                            hint: 'Budget minimun',
                            controller: _budgetMinController,
                            keyboardType: TextInputType.number,
                            suffixIcon:
                                const Icon(Icons.savings_outlined, color: AppColors.textHint),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          const Text('Maximun', style: AppTextStyles.label),
                          const SizedBox(height: AppSpacing.sm),
                          AppTextField(
                            hint: 'Budget maximun',
                            controller: _budgetMaxController,
                            keyboardType: TextInputType.number,
                            suffixIcon:
                                const Icon(Icons.savings_outlined, color: AppColors.textHint),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenPadding,
                  AppSpacing.md,
                  AppSpacing.screenPadding,
                  AppSpacing.md,
                ),
                child: PrimaryButton(label: 'Rechercher', onPressed: _search),
              ),
            ),
          ],
        );
      },
    );
  }
}
