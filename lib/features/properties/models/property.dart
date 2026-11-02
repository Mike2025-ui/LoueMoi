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
  final bool ownerHasActiveSubscription;

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
    this.ownerHasActiveSubscription = false,
    this.distanceKm,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isOccupee => status == PropertyStatus.occupee;
  bool get isVendue => status == PropertyStatus.vendue;
  bool get isAccomplie => status == PropertyStatus.accomplie;
  bool get isAnnulee => status == PropertyStatus.annulee;

  /// Annonce dont la durée de publication (30 jours) est dépassée.
  bool get isExpired => DateTime.now().difference(createdAt).inDays >= 30;

  /// Bien non réservable, quelle qu'en soit la raison (loué, vendu, accompli ou annulé).
  bool get isUnavailable => isOccupee || isVendue || isAccomplie || isAnnulee;

  /// Total réservation = loyer + caution + avance pour une location, ou prix de vente.
  double get reservationTotal => transactionType == TransactionType.vente
      ? price
      : price + (deposit ?? 0) + (advance ?? 0);

  String get locationLabel {
    final parts = [
      commune,
      district,
    ].where((s) => s.trim().isNotEmpty).toList();
    if (parts.isNotEmpty) return parts.join(', ');
    if (city.trim().isNotEmpty) return city.trim();
    return address.trim();
  }

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
      ownerHasActiveSubscription: ownerHasActiveSubscription,
      distanceKm: distanceKm ?? this.distanceKm,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return num.tryParse(value.toString())?.toDouble();
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  factory Property.fromJson(Map<String, dynamic> json) {
    final rawStatus = json['status']?.toString() ?? 'disponible';
    final expiresAtRaw = json['expires_at']?.toString();
    final expiresAt = expiresAtRaw != null
        ? DateTime.tryParse(expiresAtRaw)
        : null;
    final isExpired = expiresAt != null && expiresAt.isBefore(DateTime.now());
    final resolvedStatus = (isExpired && rawStatus == 'disponible')
        ? PropertyStatus.annulee
        : PropertyStatus.fromString(rawStatus);

    final rawIsFuture = json['is_future'];
    final isFuture =
        rawIsFuture == true ||
        rawIsFuture == 1 ||
        rawIsFuture?.toString().toLowerCase() == 'true';

    final rawIsFavorite = json['is_favorite'];
    final isFavorite =
        rawIsFavorite == true ||
        rawIsFavorite == 1 ||
        rawIsFavorite?.toString().toLowerCase() == 'true';

    final rawSub = json['owner_has_active_subscription'];
    final ownerHasActiveSubscription =
        rawSub == true ||
        rawSub == 1 ||
        rawSub?.toString().toLowerCase() == 'true';

    final parsedImages =
        (json['images'] as List?)
            ?.map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList() ??
        const <String>[];

    final rawCover = json['cover_image']?.toString() ?? '';
    final coverImage = rawCover.isNotEmpty
        ? rawCover
        : (parsedImages.isNotEmpty ? parsedImages.first : '');

    final agentJson = json['agent'];
    final Agent parsedAgent;
    if (agentJson is Map<String, dynamic>) {
      parsedAgent = Agent.fromJson(agentJson);
    } else if (agentJson is Map) {
      parsedAgent = Agent.fromJson(Map<String, dynamic>.from(agentJson));
    } else {
      parsedAgent = const Agent.empty();
    }

    return Property(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      type: PropertyType.fromString(json['type']?.toString() ?? ''),
      category: json['category']?.toString() ?? '',
      transactionType: TransactionType.fromString(
        json['transaction_type']?.toString() ?? '',
      ),
      price: _parseDouble(json['price']) ?? 0.0,
      deposit: _parseDouble(json['deposit']),
      advance: _parseDouble(json['advance']),
      city: json['city']?.toString() ?? '',
      commune: json['commune']?.toString() ?? '',
      district: json['district']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      latitude: _parseDouble(json['latitude']),
      longitude: _parseDouble(json['longitude']),
      status: resolvedStatus,
      isFuture: isFuture,
      isFavorite: isFavorite,
      images: parsedImages,
      coverImage: coverImage,
      video: _resolveVideoUrl(json['video']?.toString()),
      features:
          (json['features'] as List?)?.map((e) {
            if (e is Map) {
              final val = e['value']?.toString() ?? '';
              final key = e['key']?.toString() ?? '';
              if (key == 'pieces') return '$val pièce(s)';
              if (key == 'chambres') return '$val chambre(s)';
              if (key == 'salles_de_bain') return '$val salle(s) de bain';
              return val.isNotEmpty ? val : e.toString();
            }
            return e.toString();
          }).toList() ??
          const [],
      amenities:
          (json['amenities'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      agent: parsedAgent,
      viewsCount: _parseInt(json['views_count']) ?? 0,
      favoritesCount: _parseInt(json['favorites_count']) ?? 0,
      ownerHasActiveSubscription: ownerHasActiveSubscription,
      distanceKm: _parseDouble(json['distance_km']),
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? (DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now())
          : DateTime.now(),
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
    'owner_has_active_subscription': ownerHasActiveSubscription,
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
    ownerHasActiveSubscription,
    distanceKm,
    createdAt,
    updatedAt,
  ];
}
