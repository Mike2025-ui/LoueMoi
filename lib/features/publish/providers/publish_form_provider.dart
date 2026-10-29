import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../properties/models/property.dart';
import '../../properties/models/property_enums.dart';

class PublishFormState {
  const PublishFormState({
    this.transactionType = TransactionType.location,
    this.propertyType = PropertyType.logement,
    this.category = 'Villa',
    this.title = '',
    this.description = '',
    this.price = '',
    this.rent = '',
    this.deposit = '',
    this.advance = '',
    this.chambres = '',
    this.sallesDeBain = '',
    this.superficie = '',
    this.typeTerrain = '',
    this.characteristics = const {},
    this.city = 'Abidjan',
    this.commune = '',
    this.district = '',
    this.address = '',
    this.latitude,
    this.longitude,
    this.existingImages = const [],
    this.newImages = const [],
    this.coverImageFile,
    this.chambreImages = const [],
    this.salonImages = const [],
    this.cuisineImages = const [],
    this.salleDeBainImages = const [],
    this.existingVideoUrl,
    this.newVideo,
  });

  final TransactionType transactionType;
  final PropertyType propertyType;
  final String category;
  final String title;
  final String description;

  /// Prix de vente — uniquement pour transactionType == vente.
  final String price;

  /// Loyer/Caution/Avance — uniquement pour transactionType == location.
  final String rent;
  final String deposit;
  final String advance;

  final String chambres;
  final String sallesDeBain;
  final String superficie;

  /// Uniquement pour propertyType == terrain.
  final String typeTerrain;

  /// Caractéristiques à cocher, dont la liste d'options proposée dépend de
  /// [propertyType] (voir [characteristicsOptionsFor]).
  final Set<String> characteristics;

  final String city;
  final String commune;
  final String district;
  final String address;

  /// Position choisie via la carte ("Utiliser ma position" ou marqueur
  /// déplacé manuellement) — null tant que l'agent n'a rien confirmé. La
  /// publication reste possible sans position (compatibilité).
  final double? latitude;
  final double? longitude;

  bool get hasLocation => latitude != null && longitude != null;

  /// Photo de couverture principale (obligatoire)
  final XFile? coverImageFile;

  /// Photos de chambre(s) (obligatoire, au moins une)
  final List<XFile> chambreImages;

  /// Photos salon et terrasse (facultative)
  final List<XFile> salonImages;

  /// Photos cuisine (facultative)
  final List<XFile> cuisineImages;

  /// Photos salle(s) de bain (facultative)
  final List<XFile> salleDeBainImages;

  /// Édition uniquement : URLs déjà hébergées côté serveur.
  final List<String> existingImages;

  /// Nouvelles photos sélectionnées localement, à uploader au moment de la publication.
  final List<XFile> newImages;

  final String? existingVideoUrl;
  final XFile? newVideo;

  bool get hasCoverPhoto => coverImageFile != null || existingImages.isNotEmpty;
  bool get hasChambrePhoto =>
      chambreImages.isNotEmpty ||
      existingImages.isNotEmpty ||
      propertyType == PropertyType.terrain;
  bool get hasAtLeastOnePhoto => hasCoverPhoto && hasChambrePhoto;

  bool get hasVideo =>
      newVideo != null || (existingVideoUrl?.isNotEmpty ?? false);

  /// Liste ordonnée des nouvelles photos avec leur catégorie dédiée.
  List<({XFile file, String category, bool isCover})> get categorizedImages => [
    if (coverImageFile != null)
      (file: coverImageFile!, category: 'couverture', isCover: true),
    for (final f in chambreImages)
      (file: f, category: 'chambre', isCover: false),
    for (final f in salonImages) (file: f, category: 'salon', isCover: false),
    for (final f in cuisineImages)
      (file: f, category: 'cuisine', isCover: false),
    for (final f in salleDeBainImages)
      (file: f, category: 'salledebain', isCover: false),
  ];

  PublishFormState copyWith({
    TransactionType? transactionType,
    PropertyType? propertyType,
    String? category,
    String? title,
    String? description,
    String? price,
    String? rent,
    String? deposit,
    String? advance,
    String? chambres,
    String? sallesDeBain,
    String? superficie,
    String? typeTerrain,
    Set<String>? characteristics,
    String? city,
    String? commune,
    String? district,
    String? address,
    double? latitude,
    double? longitude,
    List<String>? existingImages,
    List<XFile>? newImages,
    XFile? coverImageFile,
    bool clearCoverImage = false,
    List<XFile>? chambreImages,
    List<XFile>? salonImages,
    List<XFile>? cuisineImages,
    List<XFile>? salleDeBainImages,
    String? existingVideoUrl,
    bool clearExistingVideoUrl = false,
    XFile? newVideo,
    bool clearNewVideo = false,
  }) {
    final nextCover = clearCoverImage
        ? null
        : (coverImageFile ?? this.coverImageFile);
    final nextChambres = chambreImages ?? this.chambreImages;
    final nextSalon = salonImages ?? this.salonImages;
    final nextCuisine = cuisineImages ?? this.cuisineImages;
    final nextSalleDeBain = salleDeBainImages ?? this.salleDeBainImages;

    // Si newImages n'est pas fourni directement, on le synchronise automatiquement
    // avec les photos catégorisées dans l'ordre strict demandé :
    // 1. Couverture, 2. Chambres, 3. Salon/Terrasse, 4. Cuisine, 5. Salles de bain
    final computedImages =
        newImages ??
        [
          ?nextCover,
          ...nextChambres,
          ...nextSalon,
          ...nextCuisine,
          ...nextSalleDeBain,
        ];

    return PublishFormState(
      transactionType: transactionType ?? this.transactionType,
      propertyType: propertyType ?? this.propertyType,
      category: category ?? this.category,
      title: title ?? this.title,
      description: description ?? this.description,
      price: price ?? this.price,
      rent: rent ?? this.rent,
      deposit: deposit ?? this.deposit,
      advance: advance ?? this.advance,
      chambres: chambres ?? this.chambres,
      sallesDeBain: sallesDeBain ?? this.sallesDeBain,
      superficie: superficie ?? this.superficie,
      typeTerrain: typeTerrain ?? this.typeTerrain,
      characteristics: characteristics ?? this.characteristics,
      city: city ?? this.city,
      commune: commune ?? this.commune,
      district: district ?? this.district,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      existingImages: existingImages ?? this.existingImages,
      newImages: computedImages,
      coverImageFile: nextCover,
      chambreImages: nextChambres,
      salonImages: nextSalon,
      cuisineImages: nextCuisine,
      salleDeBainImages: nextSalleDeBain,
      existingVideoUrl: clearExistingVideoUrl
          ? null
          : (existingVideoUrl ?? this.existingVideoUrl),
      newVideo: clearNewVideo ? null : (newVideo ?? this.newVideo),
    );
  }

  /// Pré-remplit le formulaire à partir d'une annonce existante (édition).
  factory PublishFormState.fromProperty(Property property) {
    String chambres = '';
    String sallesDeBain = '';
    String superficie = '';
    String typeTerrain = '';
    final remainingCharacteristics = <String>{};

    final allTraits = [...property.features, ...property.amenities];
    final chambreRegex = RegExp(r'^(\d+)\s*chambre', caseSensitive: false);
    final salleRegex = RegExp(r'^(\d+)\s*salle', caseSensitive: false);
    final superficieRegex = RegExp(
      r'^(\d+(?:[.,]\d+)?)\s*m²',
      caseSensitive: false,
    );

    for (final trait in allTraits) {
      final t = trait.trim();
      final chMatch = chambreRegex.firstMatch(t);
      if (chMatch != null && chambres.isEmpty) {
        chambres = chMatch.group(1) ?? '';
        continue;
      }
      final sMatch = salleRegex.firstMatch(t);
      if (sMatch != null && sallesDeBain.isEmpty) {
        sallesDeBain = sMatch.group(1) ?? '';
        continue;
      }
      final supMatch = superficieRegex.firstMatch(t);
      if (supMatch != null && superficie.isEmpty) {
        superficie = supMatch.group(1) ?? '';
        continue;
      }
      if (property.type == PropertyType.terrain &&
          (t.toLowerCase().contains('terrain') ||
              t.toLowerCase().contains('agricole') ||
              t.toLowerCase().contains('bâtir') ||
              t.toLowerCase().contains('residentiel') ||
              t.toLowerCase().contains('commercial'))) {
        if (typeTerrain.isEmpty) {
          typeTerrain = t;
          continue;
        }
      }
      remainingCharacteristics.add(t);
    }

    return PublishFormState(
      transactionType: property.transactionType,
      propertyType: property.type,
      category: property.category,
      title: property.title,
      description: property.description,
      price: property.transactionType == TransactionType.vente
          ? _fmt(property.price)
          : '',
      rent: property.transactionType == TransactionType.location
          ? _fmt(property.price)
          : '',
      deposit: property.deposit != null ? _fmt(property.deposit!) : '',
      advance: property.advance != null ? _fmt(property.advance!) : '',
      chambres: chambres,
      sallesDeBain: sallesDeBain,
      superficie: superficie,
      typeTerrain: typeTerrain,
      city: property.city,
      commune: property.commune,
      district: property.district,
      address: property.address,
      latitude: property.latitude,
      longitude: property.longitude,
      characteristics: remainingCharacteristics,
      existingImages: property.images,
      existingVideoUrl: property.video,
    );
  }

  static String _fmt(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
}

/// Options de caractéristiques proposées, selon le type de bien (section 10
/// du cahier des charges). Architecture pensée pour pouvoir en ajouter
/// d'autres plus tard sans changer la structure du formulaire.
List<String> characteristicsOptionsFor(PropertyType type) {
  switch (type) {
    case PropertyType.logement:
      return const [
        'Salon',
        'Cuisine',
        'Parking',
        'Terrasse',
        'Climatisation',
        'Eau',
        'Électricité',
        'Placard',
        'Plafonné',
        'Carrelé',
      ];
    case PropertyType.terrain:
      return const ['Document disponible', 'Lotissement', 'Viabilisé'];
    case PropertyType.magasin:
      return const [
        'Parking',
        'Climatisation',
        'Eau',
        'Électricité',
        'Sanitaires',
        'Placard',
        'Plafonné',
        'Carrelé',
      ];
  }
}

/// Volontairement PAS autoDispose : PublishScreen._loadInitial() écrit
/// l'état initial (const PublishFormState() pour une nouvelle annonce,
/// PublishFormState.fromProperty(property) — après un await réseau — pour
/// une édition) AVANT que la première page du PageView (seule à observer ce
/// provider) ne soit montée, puisque cette page n'apparaît qu'une fois
/// _loadingInitial passé à false par ce même appel. Avec autoDispose, le
/// provider n'a donc aucun watcher actif au moment de cette écriture :
/// Riverpod le libère aussitôt (faute d'observateur), et l'écriture est
/// perdue — le formulaire d'édition revenait à son état par défaut (vide)
/// au lieu des données réelles de l'annonce. Le cycle de vie de cet état
/// est de toute façon déjà entièrement piloté par PublishScreen elle-même
/// (réinitialisé explicitement à CHAQUE ouverture, aussi bien en création
/// qu'en édition) : autoDispose n'apportait donc aucun bénéfice réel ici,
/// seulement ce risque de perte de données.
final publishFormProvider = StateProvider<PublishFormState>(
  (ref) => const PublishFormState(),
);
