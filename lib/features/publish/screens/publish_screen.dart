import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:video_player/video_player.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/location_permission_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/feedback.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/geo.dart';
import '../../../core/widgets/app_map_view.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/property_image.dart';
import '../../auth/providers/auth_providers.dart';
import '../../properties/models/agent.dart';
import '../../properties/models/property.dart';
import '../../properties/models/property_enums.dart';
import '../../properties/providers/property_providers.dart';
import '../../properties/widgets/property_video_player.dart';
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

  // Publication en deux phases (créer la propriété, puis envoyer les
  // photos) : si l'upload d'une photo échoue après une création réussie,
  // on garde la propriété déjà créée et le nombre de photos déjà envoyées
  // pour qu'un nouveau clic sur "Publier" reprenne l'envoi au lieu de
  // recréer un doublon ou de renvoyer une photo déjà envoyée.
  Property? _createdProperty;
  int _uploadedImageCount = 0;
  bool _videoUploaded = false;

  bool get _isEditing => widget.editPropertyId != null;

  @override
  void initState() {
    super.initState();
    // Pour une nouvelle publication (pas une édition), _loadInitial() mute
    // publishFormProvider de façon synchrone (aucun await avant cette
    // écriture) — appelé directement depuis initState(), cela survient donc
    // pendant que l'arbre de widgets est en construction, provoquant "Tried
    // to modify a provider while the widget tree was building" (reproduit
    // sur téléphone). addPostFrameCallback reporte l'appel au frame suivant,
    // une fois le build initial terminé — la remise à zéro du formulaire
    // reste nécessaire ici (le provider n'est pas autoDispose, il faut
    // repartir d'un état vierge à chaque ouverture d'une nouvelle
    // publication) mais s'exécute désormais au bon moment.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadInitial();
    });
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
        if (form.existingImages.isEmpty) {
          if (form.coverImageFile == null) {
            return 'La photo de couverture est obligatoire.';
          }
          if (form.propertyType != PropertyType.terrain && form.chambreImages.isEmpty) {
            return 'Au moins une photo pour la ou les chambre(s) est obligatoire.';
          }
        }
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
    if (_submitting) return; // un clic pendant une publication en cours est ignoré
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
          'latitude': normalizeCoordinate(form.latitude),
          'longitude': normalizeCoordinate(form.longitude),
          'features': _buildFeatures(form),
          'amenities': form.characteristics.toList(),
        };
        saved = await repository.updateProperty(widget.editPropertyId!, payload);
      } else if (_createdProperty != null) {
        // Tentative précédente : la propriété a déjà été créée côté serveur
        // mais l'envoi d'une photo avait échoué. On ne recrée jamais la
        // propriété (pas de doublon) — on reprend seulement l'envoi des
        // photos restantes ci-dessous.
        saved = _createdProperty!;
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
        _createdProperty = saved;
      }

      // Ne renvoie que les photos pas encore envoyées avec succès — évite
      // un doublon si un clic précédent avait déjà réussi une partie de
      // l'envoi avant d'échouer sur une autre photo.
      final pendingImages = form.newImages.skip(_uploadedImageCount);
      for (final file in pendingImages) {
        saved = await repository.uploadImage(
          saved.id,
          file,
          isCover: saved.images.isEmpty,
        );
        _uploadedImageCount++;
        _createdProperty = saved;
      }

      if (form.newVideo != null && !_videoUploaded) {
        saved = await repository.uploadVideo(saved.id, form.newVideo!);
        _videoUploaded = true;
        _createdProperty = saved;
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
      if (!mounted) return;
      if (!_isEditing && _createdProperty != null) {
        // La propriété existe déjà côté serveur (créée lors d'une tentative
        // précédente ou juste avant l'échec sur cette photo) : ne jamais
        // afficher un succès, mais ne pas non plus laisser croire que rien
        // n'a été fait — l'utilisateur peut réessayer, l'envoi reprendra là
        // où il s'est arrêté (voir _uploadedImageCount ci-dessus).
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                "L'annonce a été créée mais l'envoi d'une photo ou de la vidéo a échoué "
                '(${e.toString()}). Réessayez pour terminer l\'envoi.',
              ),
            ),
          );
      } else {
        showErrorSnackbar(context, e);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Abandonne la publication depuis l'aperçu. Si une tentative précédente
  /// a déjà créé la propriété côté serveur (photo en échec, voir _submit),
  /// on la supprime pour ne pas laisser un brouillon fantôme — jamais en
  /// mode modification, où la propriété existait déjà avant cet écran.
  Future<void> _cancel() async {
    final hasData = _createdProperty != null ||
        ref.read(publishFormProvider).title.trim().isNotEmpty;
    if (hasData) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Annuler la publication ?'),
          content: Text(
            _isEditing
                ? 'Les modifications non enregistrées seront perdues.'
                : "L'annonce ne sera pas publiée.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Continuer'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Annuler'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    if (!_isEditing && _createdProperty != null) {
      try {
        await ref.read(propertyRepositoryProvider).deleteProperty(_createdProperty!.id);
      } catch (_) {
        // Best-effort : même si la suppression échoue, on ne bloque jamais
        // l'annulation — l'utilisateur ne doit pas rester coincé ici.
      }
    }
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    // Politesse de navigation : la vraie barrière est côté Django
    // (CanOwnProperties sur POST /api/properties/). Un client qui
    // atteindrait quand même cet écran (deep link, etc.) ne doit pas
    // pouvoir publier. Agent et bailleur sont tous deux habilités.
    final canPublish = ref.watch(authControllerProvider).valueOrNull?.canOwnProperties ?? false;
    if (!canPublish) {
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_step == _totalSteps - 1) ...[
                      TextButton(
                        onPressed: _submitting ? null : _cancel,
                        child: const Text('Annuler', style: AppTextStyles.link),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                    ],
                    PrimaryButton(
                      label: _step == _totalSteps - 1
                          ? (_isEditing ? 'Enregistrer' : 'Publier')
                          : 'Suivant',
                      isLoading: _submitting,
                      onPressed: _next,
                    ),
                  ],
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

  Future<void> _pickCoverPhoto(BuildContext context, WidgetRef ref, PublishFormState form) async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (picked == null) return;
      final notifier = ref.read(publishFormProvider.notifier);
      notifier.state = form.copyWith(coverImageFile: picked);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Impossible d'ouvrir la galerie de photos.")),
        );
      }
    }
  }

  Future<void> _pickMultiCategoryPhotos({
    required BuildContext context,
    required WidgetRef ref,
    required PublishFormState form,
    required List<XFile> currentList,
    required void Function(List<XFile> updated) onUpdated,
  }) async {
    try {
      final picked = await ImagePicker().pickMultiImage(imageQuality: 85);
      if (picked.isEmpty) return;
      onUpdated([...currentList, ...picked]);
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final form = ref.watch(publishFormProvider);
    final notifier = ref.read(publishFormProvider.notifier);
    final isTerrain = form.propertyType == PropertyType.terrain;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Photos du bien', style: AppTextStyles.h3),
          const SizedBox(height: AppSpacing.xs),
          const Text(
            'Sélectionnez les photos dans l’ordre recommandé pour une publication optimale.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: AppSpacing.lg),

          // 1. Photo de couverture (obligatoire)
          _PhotoCategorySection(
            title: '1. Photo de couverture',
            subtitle: 'Obligatoire — Image principale qui apparaîtra en premier sur votre annonce.',
            isRequired: form.existingImages.isEmpty,
            images: form.coverImageFile != null ? [form.coverImageFile!] : const [],
            allowMultiple: false,
            onPick: () => _pickCoverPhoto(context, ref, form),
            onRemove: (_) => notifier.state = form.copyWith(clearCoverImage: true),
          ),
          const SizedBox(height: AppSpacing.lg),

          // 2. Chambre(s) (obligatoire pour logement/magasin)
          _PhotoCategorySection(
            title: isTerrain ? '2. Photos du terrain' : '2. Chambre(s)',
            subtitle: isTerrain
                ? 'Facultatif — Vue générale ou détails du terrain.'
                : 'Obligatoire — Vous pouvez sélectionner plusieurs photos.',
            isRequired: !isTerrain && form.existingImages.isEmpty,
            images: form.chambreImages,
            onPick: () => _pickMultiCategoryPhotos(
              context: context,
              ref: ref,
              form: form,
              currentList: form.chambreImages,
              onUpdated: (list) => notifier.state = form.copyWith(chambreImages: list),
            ),
            onRemove: (f) => notifier.state = form.copyWith(
              chambreImages: form.chambreImages.where((img) => img.path != f.path).toList(),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // 3. Salon et terrasse (facultative)
          _PhotoCategorySection(
            title: '3. Salon et terrasse',
            subtitle: 'Facultative — Vous pouvez sélectionner plusieurs photos.',
            isRequired: false,
            images: form.salonImages,
            onPick: () => _pickMultiCategoryPhotos(
              context: context,
              ref: ref,
              form: form,
              currentList: form.salonImages,
              onUpdated: (list) => notifier.state = form.copyWith(salonImages: list),
            ),
            onRemove: (f) => notifier.state = form.copyWith(
              salonImages: form.salonImages.where((img) => img.path != f.path).toList(),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // 4. Cuisine (facultative)
          _PhotoCategorySection(
            title: '4. Cuisine',
            subtitle: 'Facultative — Vous pouvez sélectionner plusieurs photos.',
            isRequired: false,
            images: form.cuisineImages,
            onPick: () => _pickMultiCategoryPhotos(
              context: context,
              ref: ref,
              form: form,
              currentList: form.cuisineImages,
              onUpdated: (list) => notifier.state = form.copyWith(cuisineImages: list),
            ),
            onRemove: (f) => notifier.state = form.copyWith(
              cuisineImages: form.cuisineImages.where((img) => img.path != f.path).toList(),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // 5. Salle(s) de bain (facultative)
          _PhotoCategorySection(
            title: '5. Salle(s) de bain',
            subtitle: 'Facultative — Vous pouvez sélectionner plusieurs photos.',
            isRequired: false,
            images: form.salleDeBainImages,
            onPick: () => _pickMultiCategoryPhotos(
              context: context,
              ref: ref,
              form: form,
              currentList: form.salleDeBainImages,
              onUpdated: (list) => notifier.state = form.copyWith(salleDeBainImages: list),
            ),
            onRemove: (f) => notifier.state = form.copyWith(
              salleDeBainImages: form.salleDeBainImages.where((img) => img.path != f.path).toList(),
            ),
          ),

          // Photos déjà existantes (édition)
          if (form.existingImages.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            const Text('Photos existantes enregistrées', style: AppTextStyles.label),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final url in form.existingImages)
                  _PhotoThumb(
                    child: PropertyImage(url, fit: BoxFit.cover),
                    onRemove: () => _removeExistingImage(context, ref, form, url),
                  ),
              ],
            ),
          ],

          const Divider(height: AppSpacing.xl),
          _VideoPickerSection(editPropertyId: editPropertyId),
        ],
      ),
    );
  }
}

class _PhotoCategorySection extends StatelessWidget {
  const _PhotoCategorySection({
    required this.title,
    required this.subtitle,
    required this.isRequired,
    required this.images,
    required this.onPick,
    required this.onRemove,
    this.allowMultiple = true,
  });

  final String title;
  final String subtitle;
  final bool isRequired;
  final List<XFile> images;
  final VoidCallback onPick;
  final ValueChanged<XFile> onRemove;
  final bool allowMultiple;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      title,
                      style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isRequired) ...[
                    const SizedBox(width: 4),
                    const Text('*', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              images.isNotEmpty ? '${images.length} photo(s)' : (isRequired ? 'Requis' : 'Optionnel'),
              style: AppTextStyles.caption.copyWith(
                color: isRequired && images.isEmpty ? AppColors.danger : AppColors.textSecondary,
                fontWeight: isRequired && images.isEmpty ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(subtitle, style: AppTextStyles.caption),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final file in images)
              _PhotoThumb(
                child: Image.file(File(file.path), fit: BoxFit.cover),
                onRemove: () => onRemove(file),
              ),
            if (allowMultiple || images.isEmpty)
              InkWell(
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: onPick,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: isRequired && images.isEmpty ? AppColors.primary : AppColors.border,
                    ),
                    color: isRequired && images.isEmpty ? AppColors.primaryLight.withOpacity(0.15) : AppColors.surfaceMuted,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_photo_alternate_outlined,
                        color: isRequired && images.isEmpty ? AppColors.primary : AppColors.textHint,
                        size: 26,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        allowMultiple && images.isNotEmpty ? 'Ajouter' : 'Choisir',
                        style: TextStyle(
                          fontSize: 11,
                          color: isRequired && images.isEmpty ? AppColors.primary : AppColors.textHint,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Sélection/aperçu/remplacement/suppression de LA vidéo de l'annonce
/// (facultative, une seule au maximum). Validation client (format/taille/
/// durée) immédiate — feedback rapide avant d'atteindre la validation
/// serveur, qui reste la source de vérité (voir PropertyViewSet.upload_video).
class _VideoPickerSection extends ConsumerStatefulWidget {
  const _VideoPickerSection({required this.editPropertyId});

  final String? editPropertyId;

  @override
  ConsumerState<_VideoPickerSection> createState() => _VideoPickerSectionState();
}

class _VideoPickerSectionState extends ConsumerState<_VideoPickerSection> {
  static const _maxSizeBytes = 50 * 1024 * 1024;
  static const _maxDuration = Duration(seconds: 60);

  bool _processing = false;
  String? _error;

  Future<void> _pickVideo(PublishFormState form) async {
    setState(() {
      _processing = true;
      _error = null;
    });
    try {
      final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
      if (picked == null) {
        if (mounted) setState(() => _processing = false);
        return;
      }
      if (!picked.name.toLowerCase().endsWith('.mp4')) {
        if (mounted) {
          setState(() {
            _processing = false;
            _error = 'Format vidéo non pris en charge (MP4 uniquement).';
          });
        }
        return;
      }

      final sizeBytes = await File(picked.path).length();
      if (sizeBytes > _maxSizeBytes) {
        if (mounted) {
          setState(() {
            _processing = false;
            _error = 'La vidéo dépasse la taille maximale de 50 Mo.';
          });
        }
        return;
      }

      final controller = VideoPlayerController.file(File(picked.path));
      try {
        await controller.initialize();
        if (controller.value.duration > _maxDuration) {
          if (mounted) {
            setState(() {
              _processing = false;
              _error = 'La vidéo dépasse la durée maximale de 60 secondes.';
            });
          }
          return;
        }
      } finally {
        await controller.dispose();
      }

      final notifier = ref.read(publishFormProvider.notifier);
      notifier.state = form.copyWith(newVideo: picked, clearExistingVideoUrl: true);
      if (mounted) setState(() => _processing = false);
    } catch (_) {
      if (mounted) {
        setState(() {
          _processing = false;
          _error = 'Impossible de sélectionner la vidéo.';
        });
      }
    }
  }

  Future<void> _removeExistingVideo(BuildContext context, PublishFormState form) async {
    if (widget.editPropertyId == null) return;
    setState(() {
      _processing = true;
      _error = null;
    });
    try {
      await ref.read(propertyRepositoryProvider).deleteVideo(widget.editPropertyId!);
      final notifier = ref.read(publishFormProvider.notifier);
      notifier.state = form.copyWith(clearExistingVideoUrl: true);
    } catch (e) {
      if (context.mounted) showErrorSnackbar(context, e);
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  void _removeNewVideo(PublishFormState form) {
    final notifier = ref.read(publishFormProvider.notifier);
    notifier.state = form.copyWith(clearNewVideo: true);
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(publishFormProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Vidéo du bien (optionnel)', style: AppTextStyles.h3),
        const SizedBox(height: AppSpacing.xs),
        const Text(
          'Une vidéo MP4, 60 secondes et 50 Mo maximum.',
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: AppSpacing.md),
        if (_processing)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (form.hasVideo) ...[
          PropertyVideoPlayer(
            source: form.newVideo?.path ?? form.existingVideoUrl!,
            isLocalFile: form.newVideo != null,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Flexible(
                child: TextButton.icon(
                  onPressed: () => _pickVideo(form),
                  icon: const Icon(Icons.swap_horiz, size: 16),
                  label: const Text('Remplacer', overflow: TextOverflow.ellipsis),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: TextButton.icon(
                  onPressed: () => form.newVideo != null
                      ? _removeNewVideo(form)
                      : _removeExistingVideo(context, form),
                  icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.danger),
                  label: const Text(
                    'Supprimer',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.danger),
                  ),
                ),
              ),
            ],
          ),
        ] else
          OutlinedButton.icon(
            onPressed: () => _pickVideo(form),
            icon: const Icon(Icons.videocam_outlined, size: 18),
            label: const Text('Ajouter une vidéo'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 12),
              minimumSize: const Size.fromHeight(0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
            ),
          ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 12)),
        ],
      ],
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
