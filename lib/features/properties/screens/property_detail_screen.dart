import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/feedback.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_map_view.dart';
import '../../../core/widgets/bottom_reservation_bar.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/property_image.dart';
import '../../../core/widgets/section_divider_title.dart';
import '../../../core/widgets/status_badge.dart';
import '../../messaging/providers/message_providers.dart';
import '../../reviews/providers/review_providers.dart';
import '../../reviews/widgets/review_card.dart';
import '../models/property.dart';
import '../models/property_enums.dart';
import '../providers/property_providers.dart';
import '../widgets/agent_card.dart';
import '../widgets/property_details_table.dart';
import '../widgets/property_image_header.dart';

enum _DetailTab { apropos, gallerie, avis }

class PropertyDetailScreen extends ConsumerStatefulWidget {
  const PropertyDetailScreen({super.key, required this.propertyId});

  final String propertyId;

  @override
  ConsumerState<PropertyDetailScreen> createState() => _PropertyDetailScreenState();
}

class _PropertyDetailScreenState extends ConsumerState<PropertyDetailScreen> {
  _DetailTab _tab = _DetailTab.apropos;

  @override
  void initState() {
    super.initState();
    _registerView();
  }

  /// Incrémente le compteur de vues côté serveur — non bloquant : l'annonce
  /// s'affiche même si cet appel échoue (déjà vue, hors-ligne...).
  Future<void> _registerView() async {
    try {
      await ref.read(propertyRepositoryProvider).incrementView(widget.propertyId);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final propertyAsync = ref.watch(propertyByIdProvider(widget.propertyId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: propertyAsync.when(
        // skipLoadingOnReload : après un ref.invalidate() (ex: bascule
        // favori), on garde l'écran affiché pendant le refetch au lieu de
        // clignoter vers un spinner plein écran.
        skipLoadingOnReload: true,
        data: (property) => _Content(
          property: property,
          tab: _tab,
          onTabChanged: (t) => setState(() => _tab = t),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(
          child: Text('Impossible de charger l’annonce.', style: AppTextStyles.caption),
        ),
      ),
      bottomNavigationBar: propertyAsync.maybeWhen(
        skipLoadingOnReload: true,
        data: (property) => BottomReservationBar(
          price: property.price,
          priceSuffix: property.transactionType == TransactionType.location
              ? '/ mois'
              : '',
          isAvailable: !property.isOccupee,
          onReserve: () =>
              context.push(AppRoutes.reservationSummaryPath(property.id)),
        ),
        orElse: () => null,
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({required this.property, required this.tab, required this.onTabChanged});

  final Property property;
  final _DetailTab tab;
  final void Function(_DetailTab) onTabChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PropertyImageHeader(
            property: property,
            onBack: () => context.pop(),
            onFavoriteTap: () async {
              try {
                await toggleFavorite(ref, property.id);
              } catch (e) {
                if (context.mounted) showErrorSnackbar(context, e);
              }
            },
            onThumbnailsTap: () =>
                context.push(AppRoutes.propertyGalleryPath(property.id)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    StatusBadge.category(property.type.label),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.textSecondary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.badge),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.access_time,
                              size: 12, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            'il y a ${Formatters.relativeTime(property.createdAt)}',
                            style: AppTextStyles.small,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(property.title, style: AppTextStyles.h2),
                    ),
                    property.isOccupee
                        ? StatusBadge.occupee()
                        : (property.transactionType == TransactionType.location
                            ? StatusBadge.location()
                            : StatusBadge.vente()),
                  ],
                ),
                const SizedBox(height: 4),
                Text(Formatters.price(property.price), style: AppTextStyles.h3),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(property.locationLabel, style: AppTextStyles.caption),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    _TabButton(
                      label: 'A propos',
                      isActive: tab == _DetailTab.apropos,
                      onTap: () => onTabChanged(_DetailTab.apropos),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _TabButton(
                      label: 'Gallerie',
                      isActive: tab == _DetailTab.gallerie,
                      onTap: () => onTabChanged(_DetailTab.gallerie),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _TabButton(
                      label: 'Avis',
                      isActive: tab == _DetailTab.avis,
                      onTap: () => onTabChanged(_DetailTab.avis),
                    ),
                  ],
                ),
                const Divider(height: AppSpacing.lg),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding),
            child: switch (tab) {
              _DetailTab.apropos => _AProposTab(property: property),
              _DetailTab.gallerie => _GallerieTab(property: property),
              _DetailTab.avis => _AvisTab(property: property),
            },
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.label, required this.isActive, required this.onTap});

  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: isActive ? AppColors.primary : AppColors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isActive ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _AProposTab extends ConsumerWidget {
  const _AProposTab({required this.property});

  final Property property;

  Future<void> _contactAgent(BuildContext context, WidgetRef ref) async {
    try {
      final repository = ref.read(messageRepositoryProvider);
      final conversationId = await repository.getOrCreateConversationId(
        agentId: property.agent.id,
        propertyId: property.id,
      );
      if (!context.mounted) return;
      context.push(
        AppRoutes.conversationPath(conversationId),
        extra: {'participantName': property.agent.shortName},
      );
    } catch (e) {
      if (context.mounted) showErrorSnackbar(context, e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AgentCard(
          agent: property.agent,
          onMessageTap: () => _contactAgent(context, ref),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _contactAgent(context, ref),
            icon: const Icon(Icons.chat_bubble_outline, size: 18),
            label: const Text('Contacter l’agent'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const SectionDividerTitle(title: 'Détails'),
        const SizedBox(height: AppSpacing.md),
        const Text('Configuration', style: AppTextStyles.caption),
        const SizedBox(height: AppSpacing.sm),
        PropertyDetailsTable(property: property),
        const SizedBox(height: AppSpacing.md),
        Text(property.description, style: AppTextStyles.body),
        const SizedBox(height: AppSpacing.lg),
        const SectionDividerTitle(title: 'Localisation'),
        const SizedBox(height: AppSpacing.md),
        if (property.latitude != null && property.longitude != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: SizedBox(
              height: 180,
              child: AppMapView(
                center: LatLng(property.latitude!, property.longitude!),
                markers: [
                  AppMapMarker(
                    id: property.id,
                    latitude: property.latitude!,
                    longitude: property.longitude!,
                  ),
                ],
                interactive: false,
              ),
            ),
          )
        else
          Container(
            height: 100,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Text(
              'Position non renseignée par l’agent.',
              style: AppTextStyles.caption,
            ),
          ),
      ],
    );
  }
}

class _GallerieTab extends StatelessWidget {
  const _GallerieTab({required this.property});

  final Property property;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Gallerie: ', style: AppTextStyles.bodyMedium),
            Text('${property.images.length}', style: AppTextStyles.link),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: AppSpacing.sm,
            mainAxisSpacing: AppSpacing.sm,
            childAspectRatio: 1.3,
          ),
          itemCount: property.images.length,
          itemBuilder: (context, index) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: PropertyImage(property.images[index], fit: BoxFit.cover),
            );
          },
        ),
      ],
    );
  }
}

class _AvisTab extends ConsumerWidget {
  const _AvisTab({required this.property});

  final Property property;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(reviewsByPropertyProvider(property.id));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Les avis', style: AppTextStyles.bodyMedium),
            TextButton.icon(
              onPressed: () => _showAddReviewSheet(context, ref, property.id),
              icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
              label: const Text('Commenter', style: AppTextStyles.link),
            ),
          ],
        ),
        const Divider(),
        reviewsAsync.when(
          skipLoadingOnReload: true,
          data: (reviews) {
            if (reviews.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Center(
                  child: Text('Aucun avis pour le moment.', style: AppTextStyles.caption),
                ),
              );
            }
            return Column(
              children: reviews
                  .map((r) => Column(
                        children: [ReviewCard(review: r), const Divider()],
                      ))
                  .toList(),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Text('Impossible de charger les avis.', style: AppTextStyles.caption),
          ),
        ),
      ],
    );
  }

  void _showAddReviewSheet(BuildContext context, WidgetRef ref, String propertyId) {
    final controller = TextEditingController();
    var isSubmitting = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.screenPadding,
            right: AppSpacing.screenPadding,
            top: AppSpacing.lg,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Laisser un avis', style: AppTextStyles.h3),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: controller,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Votre commentaire...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              StatefulBuilder(
                builder: (statefulContext, setSheetState) {
                  return PrimaryButton(
                    label: 'Envoyer',
                    isLoading: isSubmitting,
                    onPressed: () async {
                      final comment = controller.text.trim();
                      if (comment.isEmpty || isSubmitting) return;
                      setSheetState(() => isSubmitting = true);
                      try {
                        await addReview(ref, propertyId: propertyId, comment: comment);
                        if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                      } catch (e) {
                        setSheetState(() => isSubmitting = false);
                        if (statefulContext.mounted) showErrorSnackbar(statefulContext, e);
                      }
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
