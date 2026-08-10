import 'package:image_picker/image_picker.dart';
import '../../../core/utils/geo.dart';
import '../../filters/models/filter_params.dart';
import '../models/property.dart';
import '../models/property_page.dart';
import 'mock_properties.dart';

/// Contrat d'accès aux propriétés. Une implémentation réelle (Dio + Django)
/// pourra remplacer [MockPropertyRepository] sans toucher aux providers/UI.
abstract class PropertyRepository {
  Future<PropertyPage> fetchProperties({FilterParams? filters, int page = 1});
  Future<Property> fetchPropertyById(String id);
  Future<Property> toggleFavorite(String id);
  Future<List<Property>> fetchFavorites();
  Future<Property> addProperty(Property property);

  /// Annonces de l'agent connecté — filtrées côté serveur (jamais en
  /// filtrant fetchProperties() côté Flutter).
  Future<List<Property>> fetchMyProperties();

  /// Modification partielle — réservée au propriétaire côté Django (403
  /// sinon). Le statut n'est jamais modifié par cet appel : pas de
  /// ré-approbation, l'annonce garde son statut courant.
  Future<Property> updateProperty(String id, Map<String, dynamic> changes);

  /// Suppression définitive — réservée au propriétaire côté Django.
  Future<void> deleteProperty(String id);

  /// Upload d'une photo (multipart). [isCover] ne fait que suggérer la
  /// photo de couverture ; Django tranche.
  Future<Property> uploadImage(String propertyId, XFile file, {bool isCover = false});

  /// Retire une photo déjà hébergée (par URL).
  Future<Property> deleteImage(String propertyId, String url);

  /// Incrémente le compteur de vues côté serveur (jamais côté Flutter).
  Future<Property> incrementView(String id);

  /// Recherche géographique — GET /api/properties/nearby/ côté API. Le
  /// calcul de distance est toujours fait côté serveur (Haversine, voir
  /// backend/properties/views.py), jamais en récupérant toutes les
  /// propriétés pour calculer les distances dans Flutter. En mode mock,
  /// même contrat mais calcul en Dart pur (core/utils/geo.dart).
  Future<List<Property>> getNearbyProperties({
    required double latitude,
    required double longitude,
    required double radiusKm,
  });

  /// Définit/modifie uniquement la position d'une annonce — réservé au
  /// propriétaire côté Django (même permission que updateProperty).
  Future<Property> updatePropertyLocation(String id, double latitude, double longitude);
}

class MockPropertyRepository implements PropertyRepository {
  final List<Property> _properties = List.of(MockProperties.all);
  static const _pageSize = 20;

  @override
  Future<PropertyPage> fetchProperties({FilterParams? filters, int page = 1}) async {
    await Future.delayed(const Duration(milliseconds: 400));
    var results = List<Property>.from(_properties);

    if (filters != null) {
      results = results
          .where((p) => p.transactionType == filters.transactionType)
          .toList();

      if (filters.commune.isNotEmpty) {
        results = results
            .where((p) =>
                p.commune.toLowerCase().contains(filters.commune.toLowerCase()))
            .toList();
      }
      if (filters.district.isNotEmpty) {
        results = results
            .where((p) =>
                p.district.toLowerCase().contains(filters.district.toLowerCase()))
            .toList();
      }
      if (filters.isFuture) {
        results = results.where((p) => p.isFuture).toList();
      }
      results = results.where((p) => p.type == filters.propertyType).toList();
      if (filters.category != null && filters.category!.isNotEmpty) {
        results = results.where((p) => p.category == filters.category).toList();
      }
      if (filters.budgetMin != null) {
        results = results.where((p) => p.price >= filters.budgetMin!).toList();
      }
      if (filters.budgetMax != null) {
        results = results.where((p) => p.price <= filters.budgetMax!).toList();
      }
    }

    final start = (page - 1) * _pageSize;
    final end = (start + _pageSize).clamp(0, results.length);
    final pageItems = start < results.length ? results.sublist(start, end) : <Property>[];

    return PropertyPage(results: pageItems, hasMore: end < results.length, count: results.length);
  }

  @override
  Future<Property> fetchPropertyById(String id) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _properties.firstWhere((p) => p.id == id);
  }

  @override
  Future<Property> toggleFavorite(String id) async {
    final index = _properties.indexWhere((p) => p.id == id);
    final updated = _properties[index].copyWith(
      isFavorite: !_properties[index].isFavorite,
    );
    _properties[index] = updated;
    return updated;
  }

  @override
  Future<List<Property>> fetchFavorites() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _properties.where((p) => p.isFavorite).toList();
  }

  @override
  Future<Property> addProperty(Property property) async {
    await Future.delayed(const Duration(milliseconds: 400));
    _properties.insert(0, property);
    return property;
  }

  @override
  Future<List<Property>> fetchMyProperties() async {
    await Future.delayed(const Duration(milliseconds: 300));
    // Un seul agent existe dans l'univers de démo : toutes les propriétés
    // mock lui appartiennent déjà.
    return _properties.where((p) => p.agent.id == MockProperties.agentKouakou.id).toList();
  }

  int _indexOrThrow(String id) {
    final index = _properties.indexWhere((p) => p.id == id);
    if (index == -1) {
      throw StateError('Propriété introuvable: $id');
    }
    return index;
  }

  @override
  Future<Property> updateProperty(String id, Map<String, dynamic> changes) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final index = _indexOrThrow(id);
    final current = _properties[index];
    final updated = Property.fromJson({...current.toJson(), ...changes});
    _properties[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteProperty(String id) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _properties.removeWhere((p) => p.id == id);
  }

  @override
  Future<Property> uploadImage(String propertyId, XFile file, {bool isCover = false}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final index = _indexOrThrow(propertyId);
    final current = _properties[index];
    final images = [...current.images, file.path];
    final updated = current.copyWith(
      images: images,
      coverImage: isCover || current.coverImage.isEmpty ? file.path : current.coverImage,
    );
    _properties[index] = updated;
    return updated;
  }

  @override
  Future<Property> deleteImage(String propertyId, String url) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final index = _indexOrThrow(propertyId);
    final current = _properties[index];
    final images = current.images.where((img) => img != url).toList();
    final updated = current.copyWith(
      images: images,
      coverImage: current.coverImage == url
          ? (images.isNotEmpty ? images.first : '')
          : current.coverImage,
    );
    _properties[index] = updated;
    return updated;
  }

  @override
  Future<Property> incrementView(String id) async {
    final index = _indexOrThrow(id);
    final current = _properties[index];
    final updated = Property.fromJson({
      ...current.toJson(),
      'views_count': current.viewsCount + 1,
    });
    _properties[index] = updated;
    return updated;
  }

  @override
  Future<List<Property>> getNearbyProperties({
    required double latitude,
    required double longitude,
    required double radiusKm,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final withDistance = _properties
        .where((p) => p.latitude != null && p.longitude != null)
        .map(
          (p) => p.copyWith(
            distanceKm: haversineKm(latitude, longitude, p.latitude!, p.longitude!),
          ),
        )
        .where((p) => p.distanceKm! <= radiusKm)
        .toList()
      ..sort((a, b) => a.distanceKm!.compareTo(b.distanceKm!));
    return withDistance;
  }

  @override
  Future<Property> updatePropertyLocation(String id, double latitude, double longitude) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final index = _indexOrThrow(id);
    final updated = _properties[index].copyWith(latitude: latitude, longitude: longitude);
    _properties[index] = updated;
    return updated;
  }
}
