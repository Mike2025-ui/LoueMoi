import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
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
import '../../auth/providers/auth_providers.dart';
import '../../messaging/providers/message_providers.dart';
import '../../payments/providers/payment_providers.dart';
import '../../payments/widgets/subscription_modal.dart';
import '../../reservations/models/reservation.dart';
import '../../reservations/providers/reservation_providers.dart';
import '../../reviews/providers/review_providers.dart';
import '../../reviews/widgets/review_card.dart';
import '../models/property.dart';
import '../models/property_enums.dart';
import '../providers/property_providers.dart';
import '../widgets/agent_card.dart';
import '../widgets/property_details_table.dart';
import '../widgets/property_image_header.dart';
import '../widgets/property_video_player.dart';

enum _DetailTab { apropos, gallerie, avis }

class PropertyDetailScreen extends ConsumerStatefulWidget {
  const PropertyDetailScreen({super.key, required this.propertyId});

  final String propertyId;

  @override
  ConsumerState<PropertyDetailScreen> createState() =>
      _PropertyDetailScreenState();
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
      await ref
          .read(propertyRepositoryProvider)
          .incrementView(widget.propertyId);
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
          child: Text(
            'Impossible de charger l’annonce.',
            style: AppTextStyles.caption,
          ),
        ),
      ),
      bottomNavigationBar: propertyAsync.maybeWhen(
        skipLoadingOnReload: true,
        data: (property) {
          final currentUser = ref.watch(authControllerProvider).valueOrNull;
          final isOwner =
              currentUser != null && currentUser.id == property.agent.id;
          if (isOwner) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                child: PrimaryButton(
                  label: 'Modifier mon annonce',
                  onPressed: () =>
                      context.push(AppRoutes.editPropertyPath(property.id)),
                ),
              ),
            );
          }
          return BottomReservationBar(
            price: property.price,
            priceSuffix: property.transactionType == TransactionType.location
                ? '/ mois'
                : '',
            isAvailable: !property.isUnavailable,
            unavailableLabel: property.isVendue
                ? 'Propriété vendue'
                : 'Propriété occupée',
            onReserve: () {
              final currentUser = ref.read(authControllerProvider).valueOrNull;
              if (currentUser == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                      'Veuillez vous connecter pour effectuer une réservation.',
                    ),
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
              final reservations =
                  ref.read(reservationsListProvider).valueOrNull ?? [];
              final alreadyReserved = reservations.any(
                (r) =>
                    r.propertyId == property.id &&
                    r.userId == currentUser.id &&
                    r.status != ReservationStatus.annulee,
              );
              if (alreadyReserved) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Vous avez déjà effectué une réservation pour cette annonce.',
                    ),
                    backgroundColor: AppColors.danger,
                  ),
                );
                return;
              }
              context.push(AppRoutes.reservationSummaryPath(property.id));
            },
          );
        },
        orElse: () => null,
      ),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({
    required this.property,
    required this.tab,
    required this.onTabChanged,
  });

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
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Row(spaceBetween) sans Expanded/Flexible sur aucun des
                // deux badges : leurs largeurs naturelles combinées
                // dépassaient la largeur d'écran sur les téléphones étroits
                // (RenderFlex overflow reproduit à 320px et 360px). Wrap
                // conserve le même rendu "poussé aux extrémités" tant que
                // les deux badges tiennent sur une ligne
                // (WrapAlignment.spaceBetween), et fait redescendre le
                // second sur une nouvelle ligne sinon — jamais de troncature
                // ni de perte d'information.
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: 4,
                  children: [
                    StatusBadge.category(property.type.label),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.textSecondary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.badge),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 12,
                            color: AppColors.textSecondary,
                          ),
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
                    switch (property.status) {
                      PropertyStatus.occupee => StatusBadge.occupee(),
                      PropertyStatus.vendue => StatusBadge.vendue(),
                      PropertyStatus.accomplie => StatusBadge.accomplie(),
                      PropertyStatus.annulee => StatusBadge.annulee(),
                      PropertyStatus.disponible =>
                        property.transactionType == TransactionType.location
                            ? StatusBadge.location()
                            : StatusBadge.vente(),
                    },
                  ],
                ),
                const SizedBox(height: 4),
                Text(Formatters.price(property.price), style: AppTextStyles.h3),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      size: 16,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(property.locationLabel, style: AppTextStyles.caption),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                // Les 3 onglets se dimensionnaient à leur contenu naturel
                // dans un Row non contraint : leur largeur combinée dépassait
                // la largeur d'écran sur tout téléphone réel (RenderFlex
                // overflow reproduit aux 5 largeurs testées, y compris
                // 412px — le débordement le plus sévère et le plus constant
                // de cet écran). Expanded fait partager la largeur
                // disponible à parts égales, comme pour MainBottomNav.
                Row(
                  children: [
                    Expanded(
                      child: _TabButton(
                        label: 'A propos',
                        isActive: tab == _DetailTab.apropos,
                        onTap: () => onTabChanged(_DetailTab.apropos),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _TabButton(
                        label: 'Gallerie',
                        isActive: tab == _DetailTab.gallerie,
                        onTap: () => onTabChanged(_DetailTab.gallerie),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _TabButton(
                        label: 'Avis',
                        isActive: tab == _DetailTab.avis,
                        onTap: () => onTabChanged(_DetailTab.avis),
                      ),
                    ),
                  ],
                ),
                const Divider(height: AppSpacing.lg),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding,
            ),
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
  const _TabButton({
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
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: isActive ? AppColors.primary : AppColors.border,
          ),
        ),
        // Centré + ellipsis en filet de sécurité : maintenant que le bouton
        // occupe une largeur partagée (Expanded) plutôt que sa largeur
        // naturelle, son contenu doit rester centré comme avant plutôt que
        // collé au bord gauche de sa nouvelle largeur.
        alignment: Alignment.center,
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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

  Future<bool> _ensureCanContact(BuildContext context, WidgetRef ref) async {
    final currentUser = ref.read(authControllerProvider).valueOrNull;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Veuillez vous connecter pour contacter le propriétaire.',
          ),
          backgroundColor: AppColors.primary,
          action: SnackBarAction(
            label: 'Se connecter',
            textColor: AppColors.white,
            onPressed: () => context.push(AppRoutes.login),
          ),
        ),
      );
      return false;
    }

    // Le propriétaire consultant son propre bien est autorisé d'office
    if (currentUser.id == property.agent.id) {
      return true;
    }

    // Vérification dynamique systématique en temps réel auprès du serveur (source de vérité absolue)
    try {
      final repository = ref.read(paymentRepositoryProvider);
      final check = await repository.checkCanContact(propertyId: property.id);
      if (check.canContact) {
        return true;
      }
    } catch (_) {}

    // Ni le propriétaire ni l'utilisateur n'ont d'abonnement actif valide -> ouvrir le modal adapté au rôle
    if (!context.mounted) return false;
    final isPro = currentUser.isAgent || currentUser.isBailleur;
    final subscribed = await showSubscriptionModal(
      context,
      isPro: isPro,
      role: currentUser.role,
      propertyId: property.id,
      reason: 'subscription_required',
    );
    if (subscribed == true) {
      ref.invalidate(propertyByIdProvider(property.id));
    }
    return subscribed == true;
  }

  Future<void> _contactAgent(BuildContext context, WidgetRef ref) async {
    final canProceed = await _ensureCanContact(context, ref);
    if (!canProceed) return;

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

  Future<void> _callAgent(
    BuildContext context,
    WidgetRef ref,
    String rawPhone,
  ) async {
    final canProceed = await _ensureCanContact(context, ref);
    if (!canProceed) return;

    var phoneToUse = rawPhone;
    if (phoneToUse.trim().isEmpty) {
      try {
        final refreshed = await ref.refresh(
          propertyByIdProvider(property.id).future,
        );
        phoneToUse = refreshed.agent.phone;
      } catch (_) {}
    }

    final cleanPhone = phoneToUse.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanPhone.isEmpty) {
      if (context.mounted) {
        showErrorSnackbar(context, "Numéro de téléphone non renseigné.");
      }
      return;
    }
    final uri = Uri(scheme: 'tel', path: cleanPhone);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else if (context.mounted) {
        showErrorSnackbar(
          context,
          "Impossible de lancer l'appel téléphonique.",
        );
      }
    } catch (e) {
      if (context.mounted) showErrorSnackbar(context, e);
    }
  }

  Future<void> _whatsappAgent(
    BuildContext context,
    WidgetRef ref,
    String rawPhone,
    String propertyTitle,
  ) async {
    final canProceed = await _ensureCanContact(context, ref);
    if (!canProceed) return;

    var phoneToUse = rawPhone;
    if (phoneToUse.trim().isEmpty) {
      try {
        final refreshed = await ref.refresh(
          propertyByIdProvider(property.id).future,
        );
        phoneToUse = refreshed.agent.whatsapp.isNotEmpty
            ? refreshed.agent.whatsapp
            : refreshed.agent.phone;
      } catch (_) {}
    }

    final cleanPhone = phoneToUse.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.isEmpty) {
      if (context.mounted) {
        showErrorSnackbar(context, "Numéro WhatsApp non renseigné.");
      }
      return;
    }
    final message =
        "Bonjour, je vous contacte depuis LoueMoi concernant votre annonce : $propertyTitle";
    final appUri = Uri.parse(
      'whatsapp://send?phone=$cleanPhone&text=${Uri.encodeComponent(message)}',
    );
    final webUri = Uri.parse(
      'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}',
    );
    try {
      if (await canLaunchUrl(appUri)) {
        await launchUrl(appUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}
    try {
      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}
    if (context.mounted) {
      showErrorSnackbar(context, "Impossible d'ouvrir WhatsApp.");
    }
  }

  Future<void> _showVisitRequestSheet(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final canProceed = await _ensureCanContact(context, ref);
    if (!canProceed) return;

    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (sheetContext) => _VisitRequestSheet(
        property: property,
        onConfirm: (date, slot, note) async {
          Navigator.of(sheetContext).pop();
          try {
            HapticFeedback.lightImpact();
            final dateStr = DateFormat('dd/MM/yyyy').format(date);
            final repository = ref.read(messageRepositoryProvider);
            final conversationId = await repository.getOrCreateConversationId(
              agentId: property.agent.id,
              propertyId: property.id,
            );
            final visitMessage =
                '📅 Demande de visite — ${property.title}\n'
                '🗓 Date souhaitée : $dateStr\n'
                '⏰ Créneau : $slot'
                '${note.isNotEmpty ? '\n💬 Note : $note' : ''}';
            await sendMessage(
              ref,
              conversationId: conversationId,
              content: visitMessage,
            );
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Votre demande de visite a été envoyée avec succès.',
                ),
                backgroundColor: AppColors.success,
              ),
            );
            context.push(
              AppRoutes.conversationPath(conversationId),
              extra: {'participantName': property.agent.shortName},
            );
          } catch (e) {
            if (context.mounted) showErrorSnackbar(context, e);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(authControllerProvider).valueOrNull;
    final isOwner = currentUser != null && currentUser.id == property.agent.id;

    void showOwnerNotice() {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Vous êtes l'auteur de cette annonce."),
          backgroundColor: AppColors.primary,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AgentCard(
          agent: property.agent,
          onMessageTap: isOwner
              ? showOwnerNotice
              : () => _contactAgent(context, ref),
          onCallTap: isOwner
              ? showOwnerNotice
              : () => _callAgent(context, ref, property.agent.phone),
          onWhatsAppTap: isOwner
              ? showOwnerNotice
              : () => _whatsappAgent(
                  context,
                  ref,
                  property.agent.whatsapp.isNotEmpty
                      ? property.agent.whatsapp
                      : property.agent.phone,
                  property.title,
                ),
        ),
        const SizedBox(height: AppSpacing.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 340;
            final visitBtn = ElevatedButton.icon(
              onPressed: isOwner
                  ? showOwnerNotice
                  : () => _showVisitRequestSheet(context, ref),
              icon: const Icon(Icons.calendar_month_outlined, size: 18),
              label: const Text(
                'Visiter ce bien',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 8,
                ),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            );

            final discussBtn = OutlinedButton.icon(
              onPressed: isOwner
                  ? showOwnerNotice
                  : () => _contactAgent(context, ref),
              icon: const Icon(Icons.chat_bubble_outline, size: 18),
              label: const Text(
                'Discuter',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            );

            if (isCompact) {
              return Column(
                children: [
                  SizedBox(width: double.infinity, child: visitBtn),
                  const SizedBox(height: AppSpacing.sm),
                  SizedBox(width: double.infinity, child: discussBtn),
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: visitBtn),
                const SizedBox(width: AppSpacing.sm),
                Expanded(child: discussBtn),
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.md),
        if (isOwner) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Vous êtes l’auteur de cette annonce.',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        const _SafetyAdviceBanner(),
        const SizedBox(height: AppSpacing.lg),
        const SectionDividerTitle(title: 'Détails'),
        const SizedBox(height: AppSpacing.md),
        const Text('Configuration', style: AppTextStyles.caption),
        const SizedBox(height: AppSpacing.sm),
        PropertyDetailsTable(property: property),
        const SizedBox(height: AppSpacing.md),
        Text(property.description, style: AppTextStyles.body),
        const SizedBox(height: AppSpacing.lg),
        _InstallationBudgetCard(property: property),
        // Vidéo facultative : rendue uniquement si l'annonce en a une, sans
        // laisser d'espace vide sinon (voir Property.video côté modèle).
        if (property.video != null && property.video!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          const SectionDividerTitle(title: 'Vidéo'),
          const SizedBox(height: AppSpacing.md),
          PropertyVideoPlayer(source: property.video!),
        ],
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
        _SimilarPropertiesSection(currentProperty: property),
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
            Row(
              children: [
                const Text('Avis & Étoiles', style: AppTextStyles.bodyMedium),
                if (reviewsAsync.valueOrNull?.isNotEmpty ?? false) ...[
                  const SizedBox(width: AppSpacing.sm),
                  const Icon(Icons.star, size: 16, color: Colors.amber),
                  const SizedBox(width: 2),
                  Text(
                    (reviewsAsync.value!.fold<double>(
                              0.0,
                              (s, r) => s + r.rating,
                            ) /
                            reviewsAsync.value!.length)
                        .toStringAsFixed(1),
                    style: AppTextStyles.caption.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    ' (${reviewsAsync.value!.length})',
                    style: AppTextStyles.caption,
                  ),
                ],
              ],
            ),
            TextButton.icon(
              onPressed: () => _showAddReviewSheet(context, ref, property),
              icon: const Icon(
                Icons.star_outline,
                size: 16,
                color: AppColors.primary,
              ),
              label: const Text('Donner mon avis', style: AppTextStyles.link),
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
                  child: Text(
                    'Aucun avis pour le moment. Soyez le premier à donner votre avis !',
                    style: AppTextStyles.caption,
                  ),
                ),
              );
            }
            return Column(
              children: reviews
                  .map(
                    (r) => Column(
                      children: [
                        ReviewCard(review: r),
                        const Divider(),
                      ],
                    ),
                  )
                  .toList(),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Text(
              'Impossible de charger les avis.',
              style: AppTextStyles.caption,
            ),
          ),
        ),
      ],
    );
  }

  void _showAddReviewSheet(
    BuildContext context,
    WidgetRef ref,
    Property property,
  ) {
    final currentUser = ref.read(authControllerProvider).valueOrNull;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez vous connecter pour laisser un avis.'),
        ),
      );
      return;
    }

    if (currentUser.id == property.agent.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vous ne pouvez pas laisser d\'avis sur votre propre annonce.',
          ),
        ),
      );
      return;
    }

    final controller = TextEditingController();
    var selectedRating = 5;
    var isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (statefulContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.screenPadding,
                right: AppSpacing.screenPadding,
                top: AppSpacing.lg,
                bottom:
                    MediaQuery.of(sheetContext).viewInsets.bottom +
                    AppSpacing.lg,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Donner mon avis', style: AppTextStyles.h3),
                  const SizedBox(height: AppSpacing.xs),
                  const Text(
                    'Partagez votre appréciation et attribuez des étoiles à cette publication.',
                    style: AppTextStyles.caption,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // Étoiles de notation interactives
                  Center(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(5, (index) {
                            final starNum = index + 1;
                            return IconButton(
                              iconSize: 36,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              constraints: const BoxConstraints(),
                              icon: Icon(
                                starNum <= selectedRating
                                    ? Icons.star
                                    : Icons.star_border,
                                color: Colors.amber,
                              ),
                              onPressed: () {
                                setSheetState(() => selectedRating = starNum);
                              },
                            );
                          }),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          switch (selectedRating) {
                            5 => '⭐⭐⭐⭐⭐ 5/5 - Excellent',
                            4 => '⭐⭐⭐⭐ 4/5 - Très bien',
                            3 => '⭐⭐⭐ 3/5 - Bien',
                            2 => '⭐⭐ 2/5 - Passable',
                            _ => '⭐ 1/5 - Décevant',
                          },
                          style: AppTextStyles.caption.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: controller,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Votre commentaire (facultatif)...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  PrimaryButton(
                    label: 'Publier mon avis',
                    isLoading: isSubmitting,
                    onPressed: () async {
                      if (isSubmitting) return;
                      final comment = controller.text.trim();
                      setSheetState(() => isSubmitting = true);
                      try {
                        await addReview(
                          ref,
                          propertyId: property.id,
                          comment: comment.isEmpty
                              ? 'Avis laissé sans commentaire écrit'
                              : comment,
                          rating: selectedRating.toDouble(),
                        );
                        if (sheetContext.mounted) {
                          Navigator.of(sheetContext).pop();
                        }
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Merci ! Votre avis a bien été publié.',
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        setSheetState(() => isSubmitting = false);
                        if (statefulContext.mounted) {
                          showErrorSnackbar(statefulContext, e);
                        }
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _VisitRequestSheet extends StatefulWidget {
  const _VisitRequestSheet({required this.property, required this.onConfirm});

  final Property property;
  final void Function(DateTime date, String slot, String note) onConfirm;

  @override
  State<_VisitRequestSheet> createState() => _VisitRequestSheetState();
}

class _VisitRequestSheetState extends State<_VisitRequestSheet> {
  late DateTime _selectedDate;
  String _selectedSlot = 'Matin (09h - 12h)';
  final _noteController = TextEditingController();

  final List<String> _slots = const [
    'Matin (09h - 12h)',
    'Après-midi (14h - 17h)',
    'Soirée (17h - 19h)',
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now().add(const Duration(days: 1));
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickCustomDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    final afterTomorrow = now.add(const Duration(days: 2));

    final isTomorrow =
        _selectedDate.year == tomorrow.year &&
        _selectedDate.month == tomorrow.month &&
        _selectedDate.day == tomorrow.day;
    final isAfterTomorrow =
        _selectedDate.year == afterTomorrow.year &&
        _selectedDate.month == afterTomorrow.month &&
        _selectedDate.day == afterTomorrow.day;
    final isCustom = !isTomorrow && !isAfterTomorrow;

    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screenPadding,
        AppSpacing.lg,
        AppSpacing.screenPadding,
        AppSpacing.lg + bottomPadding,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Demander une visite', style: AppTextStyles.h2),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Indiquez vos disponibilités pour visiter ${widget.property.title}.',
              style: AppTextStyles.caption,
            ),
            const SizedBox(height: AppSpacing.md),
            const Text('Date de visite', style: AppTextStyles.bodyMedium),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                ChoiceChip(
                  label: const Text('Demain'),
                  selected: isTomorrow,
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedDate = tomorrow);
                  },
                ),
                ChoiceChip(
                  label: const Text('Après-demain'),
                  selected: isAfterTomorrow,
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedDate = afterTomorrow);
                  },
                ),
                ActionChip(
                  avatar: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    isCustom
                        ? DateFormat('dd/MM/yyyy').format(_selectedDate)
                        : 'Autre date',
                  ),
                  onPressed: _pickCustomDate,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const Text('Créneau horaire', style: AppTextStyles.bodyMedium),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: _slots.map((slot) {
                final isSelected = _selectedSlot == slot;
                return ChoiceChip(
                  label: Text(slot),
                  selected: isSelected,
                  selectedColor: AppColors.primaryLight,
                  labelStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.textPrimary,
                  ),
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedSlot = slot);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              'Message ou question (facultatif)',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: _noteController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Ex: Je serai véhiculé...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 10,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Envoyer la demande',
              onPressed: () => widget.onConfirm(
                _selectedDate,
                _selectedSlot,
                _noteController.text.trim(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SafetyAdviceBanner extends StatelessWidget {
  const _SafetyAdviceBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warningBg.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, size: 22, color: AppColors.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Conseil de sécurité LoueMoi',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.warningText,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Ne versez jamais de frais de visite ou d’argent avant d’avoir visité les lieux en personne et vérifié le bien.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textPrimary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InstallationBudgetCard extends StatelessWidget {
  const _InstallationBudgetCard({required this.property});
  final Property property;

  @override
  Widget build(BuildContext context) {
    final isLocation = property.transactionType == TransactionType.location;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_balance_wallet_outlined,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  isLocation ? 'À prévoir pour entrer' : 'Détails financiers',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (isLocation) ...[
            _BudgetRow(
              label: '1er mois de loyer',
              amount: Formatters.price(property.price),
            ),
            if (property.deposit != null && property.deposit! > 0) ...[
              const SizedBox(height: AppSpacing.xs),
              _BudgetRow(
                label: 'Caution',
                amount: Formatters.price(property.deposit!),
              ),
            ],
            if (property.advance != null && property.advance! > 0) ...[
              const SizedBox(height: AppSpacing.xs),
              _BudgetRow(
                label: 'Avance sur loyer',
                amount: Formatters.price(property.advance!),
              ),
            ],
            const Divider(height: AppSpacing.lg),
            _BudgetRow(
              label: 'Total estimé à l’entrée',
              amount: Formatters.price(property.reservationTotal),
              isHighlight: true,
            ),
          ] else ...[
            _BudgetRow(
              label: 'Prix de vente',
              amount: Formatters.price(property.price),
              isHighlight: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _BudgetRow extends StatelessWidget {
  const _BudgetRow({
    required this.label,
    required this.amount,
    this.isHighlight = false,
  });

  final String label;
  final String amount;
  final bool isHighlight;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: isHighlight
                ? AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)
                : AppTextStyles.caption.copyWith(color: AppColors.textPrimary),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          amount,
          style: isHighlight
              ? AppTextStyles.h3.copyWith(color: AppColors.primary)
              : AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _SimilarPropertiesSection extends ConsumerWidget {
  const _SimilarPropertiesSection({required this.currentProperty});
  final Property currentProperty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cached = ref.watch(homePropertiesCacheProvider);
    final all = cached.isNotEmpty
        ? cached
        : (ref.watch(propertiesListProvider).valueOrNull ?? const []);
    final similar = all
        .where(
          (p) =>
              p.id != currentProperty.id &&
              !p.isUnavailable &&
              (p.commune.toLowerCase() ==
                      currentProperty.commune.toLowerCase() ||
                  p.category == currentProperty.category),
        )
        .take(5)
        .toList();

    if (similar.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.lg),
        const SectionDividerTitle(title: 'Biens similaires'),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 190,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: similar.length,
            separatorBuilder: (context, index) =>
                const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) {
              final item = similar[index];
              return InkWell(
                onTap: () =>
                    context.push(AppRoutes.propertyDetailPath(item.id)),
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Container(
                  width: 170,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(AppRadius.md),
                        ),
                        child: SizedBox(
                          height: 100,
                          width: double.infinity,
                          child: PropertyImage(
                            item.coverImage,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              Formatters.price(item.price),
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.title,
                              style: AppTextStyles.caption.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              item.locationLabel,
                              style: AppTextStyles.small,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
