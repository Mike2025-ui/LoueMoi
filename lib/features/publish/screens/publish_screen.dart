import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/location_permission_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/feedback.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_map_view.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/property_image.dart';
import '../../auth/providers/auth_providers.dart';
import '../../properties/models/agent.dart';
import '../../properties/models/property.dart';
import '../../properties/models/property_enums.dart';
import '../../properties/providers/property_providers.dart';
import '../providers/publish_form_provider.dart';
import '../widgets/publish_dropdown_field.dart';

/// Assistant multi-étapes de publication. Réutilisé pour la modification
/// (voir [editPropertyId]) : mêmes étapes, pré-remplies, PATCH au lieu de
/// POST. Aucune étape d'approbation — "Publier"/"Enregistrer" rend l'annonce
/// publique immédiatement (voir PropertyViewSet.perform_create côté Django).
class PublishScreen extends ConsumerStatefulWidget {
  const PublishScreen({super.key, this.editPropertyId});

  final String? editPropertyId;

  @override
  ConsumerState<PublishScreen> createState() => _PublishScreenState();
}

class _PublishScreenState extends ConsumerState<PublishScreen> {
  final _pageController = PageController();
  int _step = 0;
  static const int _totalSteps = 6;
  bool _loadingInitial = true;
  bool _submitting = false;
  String? _loadError;

  bool get _isEditing => widget.editPropertyId != null;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    if (!_isEditing) {
      ref.read(publishFormProvider.notifier).state = const PublishFormState();
      setState(() => _loadingInitial = false);
      return;
    }
    try {
      final repository = ref.read(propertyRepositoryProvider);
      final property = await repository.fetchPropertyById(widget.editPropertyId!);
      ref.read(publishFormProvider.notifier).state = PublishFormState.fromProperty(property);
      setState(() => _loadingInitial = false);
    } catch (e) {
      setState(() {
        _loadingInitial = false;
        _loadError = "Impossible de charger l'annonce à modifier.";
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String? _validateStep(int step) {
    final form = ref.read(publishFormProvider);
    switch (step) {
      case 1:
        if (form.title.trim().isEmpty) return 'Le titre est obligatoire.';
        final price = form.transactionType == TransactionType.vente ? form.price : form.rent;
        if (price.trim().isEmpty || (double.tryParse(price) ?? 0) <= 0) {
          return form.transactionType == TransactionType.vente
              ? 'Indiquez un prix de vente valide.'
              : 'Indiquez un loyer valide.';
        }
        return null;
      case 3:
        if (form.commune.trim().isEmpty || form.district.trim().isEmpty) {
          return 'Commune et quartier sont obligatoires.';
        }
        return null;
      case 4:
        if (!form.hasAtLeastOnePhoto) return 'Ajoutez au moins une photo.';
        return null;
      default:
        return null;
    }
  }

  void _next() {
    final error = _validateStep(_step);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    if (_step < _totalSteps - 1) {
      setState(() => _step++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      _submit();
    }
  }

  void _back() {
    if (_step == 0) {
      context.pop();
      return;
    }
    setState(() => _step--);
    _pageController.previousPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  List<String> _buildFeatures(PublishFormState form) {
    return [
      if (form.propertyType == PropertyType.logement) ...[
        if (form.chambres.trim().isNotEmpty) '${form.chambres.trim()} chambre(s)',
        if (form.sallesDeBain.trim().isNotEmpty) '${form.sallesDeBain.trim()} salle(s) de bain',
      ],
      if (form.propertyType == PropertyType.terrain && form.typeTerrain.trim().isNotEmpty)
        form.typeTerrain.trim(),
      if (form.superficie.trim().isNotEmpty) '${form.superficie.trim()} m²',
    ];
  }

  Future<void> _submit() async {
    final error = _validateStep(4);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    setState(() => _submitting = true);
    final form = ref.read(publishFormProvider);
    final repository = ref.read(propertyRepositoryProvider);
    final priceValue = double.tryParse(
          form.transactionType == TransactionType.vente ? form.price : form.rent,
        ) ??
        0;
    final isLocation = form.transactionType == TransactionType.location;

    try {
      Property saved;
      if (_isEditing) {
        final payload = <String, dynamic>{
          'title': form.title.trim(),
          'description': form.description.trim(),
          'type': form.propertyType.name,
          'category': form.category,
          'transaction_type': form.transactionType.name,
          'price': priceValue,
          'deposit': isLocation && form.deposit.trim().isNotEmpty
              ? double.tryParse(form.deposit)
              : null,
          'advance': isLocation && form.advance.trim().isNotEmpty
              ? double.tryParse(form.advance)
              : null,
          'city': form.city,
          'commune': form.commune.trim(),
          'district': form.district.trim(),
          'address': form.address.trim(),
          'latitude': form.latitude,
          'longitude': form.longitude,
          'features': _buildFeatures(form),
          'amenities': form.characteristics.toList(),
        };
        saved = await repository.updateProperty(widget.editPropertyId!, payload);
      } else {
        final user = ref.read(authControllerProvider).valueOrNull;
        final now = DateTime.now();
        final draft = Property(
          id: 'draft',
          title: form.title.trim(),
          description: form.description.trim(),
          type: form.propertyType,
          category: form.category,
          transactionType: form.transactionType,
          price: priceValue,
          deposit:
              isLocation && form.deposit.trim().isNotEmpty ? double.tryParse(form.deposit) : null,
          advance:
              isLocation && form.advance.trim().isNotEmpty ? double.tryParse(form.advance) : null,
          city: form.city,
          commune: form.commune.trim(),
          district: form.district.trim(),
          address: form.address.trim(),
          latitude: form.latitude,
          longitude: form.longitude,
          status: PropertyStatus.disponible,
          images: const [],
          coverImage: '',
          features: _buildFeatures(form),
          amenities: form.characteristics.toList(),
          agent: Agent(
            id: user?.id ?? '',
            firstName: user?.firstName ?? '',
            lastName: user?.lastName ?? '',
            phone: user?.phone ?? '',
            whatsapp: user?.whatsapp ?? '',
            photo: user?.photo,
            isVerified: user?.agentProfile?.isVerified ?? false,
            rating: user?.agentProfile?.rating ?? 0,
          ),
          createdAt: now,
          updatedAt: now,
        );
        saved = await repository.addProperty(draft);
      }

      for (final file in form.newImages) {
        saved = await repository.uploadImage(
          saved.id,
          file,
          isCover: saved.images.isEmpty,
        );
      }

      ref.invalidate(propertiesListProvider);
      ref.invalidate(myPropertiesProvider);
      if (_isEditing) ref.invalidate(propertyByIdProvider(widget.editPropertyId!));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Annonce modifiée avec succès.' : 'Annonce publiée avec succès.'),
        ),
      );
      context.pop();
    } catch (e) {
      if (mounted) showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Politesse de navigation : la vraie barrière est côté Django
    // (IsAgent sur POST /api/properties/). Un client qui atteindrait quand
    // même cet écran (deep link, etc.) ne doit pas pouvoir publier.
    final isAgent = ref.watch(authControllerProvider).valueOrNull?.isAgent ?? false;
    if (!isAgent) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Publier une propriété')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.screenPadding),
            child: Text(
              'La publication d’annonces est réservée aux agents immobiliers.',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption,
            ),
          ),
        ),
      );
    }

    if (_loadingInitial) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: Text(_isEditing ? "Modifier l'annonce" : 'Publier une propriété')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text("Modifier l'annonce")),
        body: Center(child: Text(_loadError!, style: AppTextStyles.caption)),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _back();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(_isEditing ? "Modifier l'annonce" : 'Publier une propriété'),
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _back),
        ),
        body: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  const _StepTransactionAndType(),
                  const _StepGeneralInfo(),
                  const _StepCharacteristics(),
                  const _StepLocalisation(),
                  _StepPhotos(editPropertyId: widget.editPropertyId),
                  const _StepPreview(),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                child: PrimaryButton(
                  label: _step == _totalSteps - 1
                      ? (_isEditing ? 'Enregistrer' : 'Publier')
                      : 'Suivant',
                  isLoading: _submitting,
                  onPressed: _next,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepTransactionAndType extends ConsumerWidget {
  const _StepTransactionAndType();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final form = ref.watch(publishFormProvider);
    final notifier = ref.read(publishFormProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Type de transaction', style: AppTextStyles.h3),
          const SizedBox(height: AppSpacing.md),
          PublishDropdownField<TransactionType>(
            label: "Type d'offre",
            value: form.transactionType,
            items: TransactionType.values,
            itemLabel: (v) => v.label,
            onChanged: (v) => notifier.state = form.copyWith(transactionType: v),
          ),
          const SizedBox(height: AppSpacing.md),
          PublishDropdownField<PropertyType>(
            label: 'Type de propriété',
            value: form.propertyType,
            items: PropertyType.values,
            itemLabel: (v) => v.label,
            onChanged: (v) {
              final categories = _categoriesFor(v);
              notifier.state = form.copyWith(
                propertyType: v,
                category: categories.first,
              );
            },
          ),
        ],
      ),
    );
  }
}

List<String> _categoriesFor(PropertyType type) => switch (type) {
      PropertyType.logement => AppConstants.logementCategories,
      PropertyType.terrain => AppConstants.terrainCategories,
      PropertyType.magasin => AppConstants.magasinCategories,
    };

class _StepGeneralInfo extends ConsumerStatefulWidget {
  const _StepGeneralInfo();

  @override
  ConsumerState<_StepGeneralInfo> createState() => _StepGeneralInfoState();
}

class _StepGeneralInfoState extends ConsumerState<_StepGeneralInfo> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _rentCtrl;
  late final TextEditingController _depositCtrl;
  late final TextEditingController _advanceCtrl;

  @override
  void initState() {
    super.initState();
    final form = ref.read(publishFormProvider);
    _titleCtrl = TextEditingController(text: form.title);
    _descCtrl = TextEditingController(text: form.description);
    _priceCtrl = TextEditingController(text: form.price);
    _rentCtrl = TextEditingController(text: form.rent);
    _depositCtrl = TextEditingController(text: form.deposit);
    _advanceCtrl = TextEditingController(text: form.advance);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _rentCtrl.dispose();
    _depositCtrl.dispose();
    _advanceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(publishFormProvider);
    final notifier = ref.read(publishFormProvider.notifier);
    final categories = _categoriesFor(form.propertyType);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(
            label: "Titre de l'annonce",
            hint: 'Ex: Appartement meublé',
            controller: _titleCtrl,
            onChanged: (v) => notifier.state = form.copyWith(title: v),
          ),
          const SizedBox(height: AppSpacing.md),
          PublishDropdownField<String>(
            label: 'Catégorie',
            value: categories.contains(form.category) ? form.category : categories.first,
            items: categories,
            itemLabel: (v) => v,
            onChanged: (v) => notifier.state = form.copyWith(category: v),
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'Description',
            hint: 'Décrivez le bien en quelques phrases',
            maxLines: 5,
            controller: _descCtrl,
            onChanged: (v) => notifier.state = form.copyWith(description: v),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (form.transactionType == TransactionType.vente)
            AppTextField(
              label: 'Prix de vente (Fcfa)',
              hint: 'Prix de vente',
              keyboardType: TextInputType.number,
              controller: _priceCtrl,
              onChanged: (v) => notifier.state = form.copyWith(price: v),
            )
          else ...[
            AppTextField(
              label: 'Loyer mensuel (Fcfa)',
              hint: 'Loyer mensuel',
              keyboardType: TextInputType.number,
              controller: _rentCtrl,
              onChanged: (v) => notifier.state = form.copyWith(rent: v),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Caution (Fcfa)',
              hint: 'Caution',
              keyboardType: TextInputType.number,
              controller: _depositCtrl,
              onChanged: (v) => notifier.state = form.copyWith(deposit: v),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              label: 'Avance (Fcfa)',
              hint: 'Avance',
              keyboardType: TextInputType.number,
              controller: _advanceCtrl,
              onChanged: (v) => notifier.state = form.copyWith(advance: v),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepCharacteristics extends ConsumerStatefulWidget {
  const _StepCharacteristics();

  @override
  ConsumerState<_StepCharacteristics> createState() => _StepCharacteristicsState();
}

class _StepCharacteristicsState extends ConsumerState<_StepCharacteristics> {
  late final TextEditingController _chambresCtrl;
  late final TextEditingController _sallesCtrl;
  late final TextEditingController _superficieCtrl;
  late final TextEditingController _typeTerrainCtrl;

  @override
  void initState() {
    super.initState();
    final form = ref.read(publishFormProvider);
    _chambresCtrl = TextEditingController(text: form.chambres);
    _sallesCtrl = TextEditingController(text: form.sallesDeBain);
    _superficieCtrl = TextEditingController(text: form.superficie);
    _typeTerrainCtrl = TextEditingController(text: form.typeTerrain);
  }

  @override
  void dispose() {
    _chambresCtrl.dispose();
    _sallesCtrl.dispose();
    _superficieCtrl.dispose();
    _typeTerrainCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(publishFormProvider);
    final notifier = ref.read(publishFormProvider.notifier);
    final options = characteristicsOptionsFor(form.propertyType);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (form.propertyType == PropertyType.logement) ...[
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    label: 'Chambres',
                    hint: 'Nombre de chambres',
                    keyboardType: TextInputType.number,
                    controller: _chambresCtrl,
                    onChanged: (v) => notifier.state = form.copyWith(chambres: v),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppTextField(
                    label: 'Salles de bain',
                    hint: 'Nombre',
                    keyboardType: TextInputType.number,
                    controller: _sallesCtrl,
                    onChanged: (v) => notifier.state = form.copyWith(sallesDeBain: v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          if (form.propertyType == PropertyType.terrain) ...[
            AppTextField(
              label: 'Type de terrain',
              hint: 'Ex: Terrain nu, agricole...',
              controller: _typeTerrainCtrl,
              onChanged: (v) => notifier.state = form.copyWith(typeTerrain: v),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          AppTextField(
            label: 'Superficie (m²)',
            hint: 'Superficie',
            keyboardType: TextInputType.number,
            controller: _superficieCtrl,
            onChanged: (v) => notifier.state = form.copyWith(superficie: v),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text('Caractéristiques', style: AppTextStyles.label),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: options.map((option) {
              final isSelected = form.characteristics.contains(option);
              return FilterChip(
                label: Text(option),
                selected: isSelected,
                onSelected: (selected) {
                  final updated = Set<String>.from(form.characteristics);
                  if (selected) {
                    updated.add(option);
                  } else {
                    updated.remove(option);
                  }
                  notifier.state = form.copyWith(characteristics: updated);
                },
                selectedColor: AppColors.primaryLight,
                checkmarkColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  side: BorderSide(
                    color: isSelected ? AppColors.primary : AppColors.border,
                  ),
                ),
                backgroundColor: AppColors.white,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _StepLocalisation extends ConsumerStatefulWidget {
  const _StepLocalisation();

  @override
  ConsumerState<_StepLocalisation> createState() => _StepLocalisationState();
}

class _StepLocalisationState extends ConsumerState<_StepLocalisation> {
  late final TextEditingController _cityCtrl;
  late final TextEditingController _communeCtrl;
  late final TextEditingController _districtCtrl;
  late final TextEditingController _addressCtrl;
  final _mapController = MapController();
  bool _locating = false;

  // Cocody, Abidjan — centre par défaut tant qu'aucune position n'est choisie.
  static const _defaultCenter = LatLng(5.359951, -4.008256);

  @override
  void initState() {
    super.initState();
    final form = ref.read(publishFormProvider);
    _cityCtrl = TextEditingController(text: form.city);
    _communeCtrl = TextEditingController(text: form.commune);
    _districtCtrl = TextEditingController(text: form.district);
    _addressCtrl = TextEditingController(text: form.address);
  }

  @override
  void dispose() {
    _cityCtrl.dispose();
    _communeCtrl.dispose();
    _districtCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  void _setPosition(double latitude, double longitude) {
    final form = ref.read(publishFormProvider);
    ref.read(publishFormProvider.notifier).state =
        form.copyWith(latitude: latitude, longitude: longitude);
    _mapController.move(LatLng(latitude, longitude), _mapController.camera.zoom);
  }

  Future<void> _useMyPosition() async {
    setState(() => _locating = true);
    final result = await const LocationPermissionService().getCurrentPosition();
    if (!mounted) return;
    setState(() => _locating = false);
    if (!result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message ?? 'Localisation indisponible.')),
      );
      return;
    }
    _setPosition(result.latitude!, result.longitude!);
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(publishFormProvider);
    final notifier = ref.read(publishFormProvider.notifier);
    final center = form.hasLocation ? LatLng(form.latitude!, form.longitude!) : _defaultCenter;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppTextField(
            label: 'Ville',
            hint: 'Ville',
            controller: _cityCtrl,
            onChanged: (v) => notifier.state = form.copyWith(city: v),
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'Commune',
            hint: 'Commune',
            suffixIcon: const Icon(Icons.my_location, color: AppColors.textHint),
            controller: _communeCtrl,
            onChanged: (v) => notifier.state = form.copyWith(commune: v),
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'Quartier',
            hint: 'Quartier',
            suffixIcon: const Icon(Icons.my_location, color: AppColors.textHint),
            controller: _districtCtrl,
            onChanged: (v) => notifier.state = form.copyWith(district: v),
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'Adresse (optionnel)',
            hint: 'Adresse précise',
            controller: _addressCtrl,
            onChanged: (v) => notifier.state = form.copyWith(address: v),
          ),
          const SizedBox(height: AppSpacing.lg),
          const Text('Position sur la carte (optionnel)', style: AppTextStyles.label),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Utilisez votre position actuelle ou touchez la carte pour placer le repère.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: SizedBox(
              height: 220,
              child: AppMapView(
                center: center,
                mapController: _mapController,
                markers: form.hasLocation
                    ? [
                        AppMapMarker(
                          id: 'selected',
                          latitude: form.latitude!,
                          longitude: form.longitude!,
                        ),
                      ]
                    : const [],
                onTap: (point) => _setPosition(point.latitude, point.longitude),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: _locating ? null : _useMyPosition,
            icon: _locating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location, size: 18),
            label: const Text('Utiliser ma position'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 12),
              minimumSize: const Size.fromHeight(0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            form.hasLocation
                ? 'Position définie (${form.latitude!.toStringAsFixed(5)}, ${form.longitude!.toStringAsFixed(5)})'
                : 'Aucune position définie — l’annonce reste publiable sans elle.',
            style: AppTextStyles.small,
          ),
        ],
      ),
    );
  }
}

class _StepPhotos extends ConsumerWidget {
  const _StepPhotos({required this.editPropertyId});

  final String? editPropertyId;

  Future<void> _pickImages(BuildContext context, WidgetRef ref, PublishFormState form) async {
    try {
      final picked = await ImagePicker().pickMultiImage(imageQuality: 85);
      if (picked.isEmpty) return;
      final notifier = ref.read(publishFormProvider.notifier);
      notifier.state = form.copyWith(newImages: [...form.newImages, ...picked]);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Impossible d'ouvrir la galerie de photos.")),
        );
      }
    }
  }

  Future<void> _removeExistingImage(
    BuildContext context,
    WidgetRef ref,
    PublishFormState form,
    String url,
  ) async {
    if (editPropertyId == null) return;
    try {
      final repository = ref.read(propertyRepositoryProvider);
      await repository.deleteImage(editPropertyId!, url);
      final notifier = ref.read(publishFormProvider.notifier);
      notifier.state = form.copyWith(
        existingImages: form.existingImages.where((img) => img != url).toList(),
      );
    } catch (e) {
      if (context.mounted) showErrorSnackbar(context, e);
    }
  }

  void _removeNewImage(WidgetRef ref, PublishFormState form, XFile file) {
    final notifier = ref.read(publishFormProvider.notifier);
    notifier.state = form.copyWith(
      newImages: form.newImages.where((f) => f.path != file.path).toList(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final form = ref.watch(publishFormProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Photos du bien', style: AppTextStyles.h3),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'La première photo devient la photo principale.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final url in form.existingImages)
                _PhotoThumb(
                  child: PropertyImage(url, fit: BoxFit.cover),
                  onRemove: () => _removeExistingImage(context, ref, form, url),
                ),
              for (final file in form.newImages)
                _PhotoThumb(
                  child: Image.file(File(file.path), fit: BoxFit.cover),
                  onRemove: () => _removeNewImage(ref, form, file),
                ),
              InkWell(
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: () => _pickImages(context, ref, form),
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(Icons.add_photo_alternate_outlined,
                      color: AppColors.textHint, size: 28),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({required this.child, required this.onRemove});

  final Widget child;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      height: 100,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: child,
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: InkWell(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: AppColors.overlayDark,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 16, color: AppColors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepPreview extends ConsumerWidget {
  const _StepPreview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final form = ref.watch(publishFormProvider);
    final priceValue = double.tryParse(
          form.transactionType == TransactionType.vente ? form.price : form.rent,
        ) ??
        0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Aperçu de votre annonce', style: AppTextStyles.h3),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: AspectRatio(
              aspectRatio: 1.5,
              child: form.newImages.isNotEmpty
                  ? Image.file(File(form.newImages.first.path), fit: BoxFit.cover)
                  : form.existingImages.isNotEmpty
                      ? PropertyImage(form.existingImages.first, fit: BoxFit.cover)
                      : Container(color: AppColors.surfaceMuted),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(form.title.isEmpty ? '(Sans titre)' : form.title, style: AppTextStyles.h3),
          const SizedBox(height: 4),
          Text(Formatters.price(priceValue), style: AppTextStyles.priceSm),
          const SizedBox(height: 4),
          Text(form.category, style: AppTextStyles.caption),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.location_on, size: 14, color: AppColors.primary),
              const SizedBox(width: 2),
              Expanded(
                child: Text('${form.commune}, ${form.district}', style: AppTextStyles.small),
              ),
            ],
          ),
          if (form.description.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(form.description, style: AppTextStyles.body),
          ],
          if (form.characteristics.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: form.characteristics
                  .map((c) => Chip(
                        label: Text(c),
                        backgroundColor: AppColors.primaryLight,
                        labelStyle: const TextStyle(color: AppColors.primary),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}
