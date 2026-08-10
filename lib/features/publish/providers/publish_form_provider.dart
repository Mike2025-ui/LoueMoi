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

  /// Édition uniquement : URLs déjà hébergées côté serveur. L'agent peut en
  /// retirer (bouton supprimer) ; jamais réordonnées par glisser-déposer
  /// dans cette phase — la première de la liste sert de photo principale.
  final List<String> existingImages;

  /// Nouvelles photos sélectionnées localement (image_picker), à uploader
  /// au moment de la publication/modification.
  final List<XFile> newImages;

  bool get hasAtLeastOnePhoto => existingImages.isNotEmpty || newImages.isNotEmpty;

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
  }) {
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
      newImages: newImages ?? this.newImages,
    );
  }

  /// Pré-remplit le formulaire à partir d'une annonce existante (édition).
  factory PublishFormState.fromProperty(Property property) {
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
      city: property.city,
      commune: property.commune,
      district: property.district,
      address: property.address,
      latitude: property.latitude,
      longitude: property.longitude,
      characteristics: {...property.features, ...property.amenities},
      existingImages: property.images,
    );
  }

  static String _fmt(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : value.toString();
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
      ];
    case PropertyType.terrain:
      return const ['Document disponible', 'Lotissement', 'Viabilisé'];
    case PropertyType.magasin:
      return const ['Parking', 'Climatisation', 'Eau', 'Électricité', 'Sanitaires'];
  }
}

final publishFormProvider =
    StateProvider.autoDispose<PublishFormState>((ref) => const PublishFormState());
