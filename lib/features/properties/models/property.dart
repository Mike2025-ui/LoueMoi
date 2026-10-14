import 'package:equatable/equatable.dart';
import '../../../core/config/env.dart';
import '../../../core/utils/geo.dart';
import 'agent.dart';
import 'property_enums.dart';

class Property extends Equatable {
  final String id;
  final String title;
  final String description;
  final PropertyType type;
  final String category; // Villa, Studio, Appart, Terrain, Magasin...
  final TransactionType transactionType;
  final double price;
  final double? deposit; // Caution
  final double? advance; // Avance
  final String city;
  final String commune;
  final String district;
  final String address;
  final double? latitude;
  final double? longitude;
  final PropertyStatus status;
  final bool isFuture;
  final bool isFavorite;
  final List<String> images;
  final String coverImage;

  /// Vidéo facultative de l'annonce (une seule au maximum) — URL absolue
  /// hébergée côté serveur, null tant qu'aucune vidéo n'a été envoyée.
  /// Fonctionnalité distincte de la vidéo de messagerie : jamais mélangée.
  final String? video;
  final List<String> features; // Douche, Cuisine, Parking...
  final List<String> amenities; // Eau, Courant...
  final Agent agent;
  final int viewsCount;
  final int favoritesCount;

  /// Non-null uniquement pour les résultats de recherche à proximité
  /// (GET /api/properties/nearby/) — calculée côté serveur, jamais
  /// recalculée côté Flutter.
  final double? distanceKm;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Property({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.category,
    required this.transactionType,
    required this.price,
    this.deposit,
    this.advance,
    required this.city,
    required this.commune,
    required this.district,
    required this.address,
    this.latitude,
    this.longitude,
    required this.status,
    this.isFuture = false,
    this.isFavorite = false,
    required this.images,
    required this.coverImage,
    this.video,
    required this.features,
    required this.amenities,
    required this.agent,
    this.viewsCount = 0,
    this.favoritesCount = 0,
    this.distanceKm,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isOccupee => status == PropertyStatus.occupee;
  bool get isVendue => status == PropertyStatus.vendue;

  /// Bien non réservable, quelle qu'en soit la raison (loué ou vendu) —
  /// jamais les deux à la fois : "occupee" n'existe que pour une location,
  /// "vendue" que pour une vente (voir PropertyStatus).
  bool get isUnavailable => isOccupee || isVendue;

  /// Total réservation = loyer + caution + avance (calcul dynamique).
  double get reservationTotal => price + (deposit ?? 0) + (advance ?? 0);

  String get locationLabel => '$commune,$district';

  Property copyWith({
    bool? isFavorite,
    PropertyStatus? status,
    List<String>? images,
    String? coverImage,
    int? favoritesCount,
    double? latitude,
    double? longitude,
    double? distanceKm,
  }) {
    return Property(
      id: id,
      title: title,
      description: description,
      type: type,
      category: category,
      transactionType: transactionType,
      price: price,
      deposit: deposit,
      advance: advance,
      city: city,
      commune: commune,
      district: district,
      address: address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      status: status ?? this.status,
      isFuture: isFuture,
      isFavorite: isFavorite ?? this.isFavorite,
      images: images ?? this.images,
      coverImage: coverImage ?? this.coverImage,
      features: features,
      amenities: amenities,
      agent: agent,
      viewsCount: viewsCount,
      favoritesCount: favoritesCount ?? this.favoritesCount,
      distanceKm: distanceKm ?? this.distanceKm,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  factory Property.fromJson(Map<String, dynamic> json) {
    return Property(
      id: json['id'].toString(),
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      type: PropertyType.fromString(json['type'] as String),
      category: json['category'] as String,
      transactionType:
          TransactionType.fromString(json['transaction_type'] as String),
      price: (json['price'] as num).toDouble(),
      deposit: (json['deposit'] as num?)?.toDouble(),
      advance: (json['advance'] as num?)?.toDouble(),
      city: json['city'] as String? ?? '',
      commune: json['commune'] as String,
      district: json['district'] as String,
      address: json['address'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      status: PropertyStatus.fromString(json['status'] as String),
      isFuture: json['is_future'] as bool? ?? false,
      isFavorite: json['is_favorite'] as bool? ?? false,
      images: (json['images'] as List).map((e) => e as String).toList(),
      coverImage: json['cover_image'] as String,
      video: _resolveVideoUrl(json['video'] as String?),
      features: (json['features'] as List).map((e) => e as String).toList(),
      amenities: (json['amenities'] as List).map((e) => e as String).toList(),
      agent: Agent.fromJson(json['agent'] as Map<String, dynamic>),
      viewsCount: json['views_count'] as int? ?? 0,
      favoritesCount: json['favorites_count'] as int? ?? 0,
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Le backend renvoie normalement déjà une URL absolue (voir
  /// PropertyViewSet.get_serializer_context côté Django, qui fournit
  /// `request` à DRF pour que FileField.to_representation construise l'URL
  /// via request.build_absolute_uri() plutôt que de renvoyer un simple
  /// "/media/..."). Ce filet de sécurité ne fait que compléter une URL
  /// relative avec Env.apiBaseUrl si jamais elle en arrivait une malgré
  /// tout — sans lui, video_player recevrait une URI sans schéma ni hôte et
  /// échouerait silencieusement (voir PropertyVideoPlayer._init).
  static String? _resolveVideoUrl(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    final base = Env.apiBaseUrl;
    return raw.startsWith('/') ? '$base$raw' : '$base/$raw';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'type': type.name,
        'category': category,
        'transaction_type': transactionType.name,
        'price': price,
        'deposit': deposit,
        'advance': advance,
        'city': city,
        'commune': commune,
        'district': district,
        'address': address,
        'latitude': normalizeCoordinate(latitude),
        'longitude': normalizeCoordinate(longitude),
        'status': status.name,
        'is_future': isFuture,
        'is_favorite': isFavorite,
        'images': images,
        'cover_image': coverImage,
        'video': video,
        'features': features,
        'amenities': amenities,
        'agent': agent.toJson(),
        'views_count': viewsCount,
        'favorites_count': favoritesCount,
        if (distanceKm != null) 'distance_km': distanceKm,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        type,
        category,
        transactionType,
        price,
        deposit,
        advance,
        city,
        commune,
        district,
        address,
        status,
        isFuture,
        isFavorite,
        images,
        coverImage,
        video,
        features,
        amenities,
        agent,
        viewsCount,
        favoritesCount,
        distanceKm,
        createdAt,
        updatedAt,
      ];
}
