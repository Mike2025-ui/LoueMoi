import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/api_exceptions.dart';
import '../../filters/models/filter_params.dart';
import '../models/property.dart';
import '../models/property_page.dart';
import 'property_repository.dart';

/// Implémentation réelle, branchée sur `/api/properties/` (Django REST +
/// django-filter + pagination). Le contrat [PropertyRepository] reste
/// identique à [MockPropertyRepository] : aucun écran n'a besoin de changer.
class ApiPropertyRepository implements PropertyRepository {
  ApiPropertyRepository(this._apiClient);

  final ApiClient _apiClient;

  Map<String, dynamic> _filtersToQuery(FilterParams? filters, int page) {
    final query = <String, dynamic>{'page': page};
    if (filters == null) return query;

    query['transaction_type'] = filters.transactionType.name;
    query['type'] = filters.propertyType.name;
    if (filters.commune.isNotEmpty) query['commune'] = filters.commune;
    if (filters.district.isNotEmpty) query['district'] = filters.district;
    if (filters.isFuture) query['is_future'] = true;
    if (filters.category != null && filters.category!.isNotEmpty) {
      query['category'] = filters.category;
    }
    if (filters.budgetMin != null) query['budget_min'] = filters.budgetMin;
    if (filters.budgetMax != null) query['budget_max'] = filters.budgetMax;
    return query;
  }

  PropertyPage _parsePage(Map<String, dynamic> data) {
    final results = (data['results'] as List)
        .map((json) => Property.fromJson(json as Map<String, dynamic>))
        .toList();
    return PropertyPage(
      results: results,
      hasMore: data['next'] != null,
      count: data['count'] as int? ?? results.length,
    );
  }

  @override
  Future<PropertyPage> fetchProperties({FilterParams? filters, int page = 1}) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.properties,
      query: _filtersToQuery(filters, page),
    );
    return _parsePage(response.data!);
  }

  @override
  Future<Property> fetchPropertyById(String id) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.propertyDetail(id),
    );
    return Property.fromJson(response.data!);
  }

  @override
  Future<Property> toggleFavorite(String id) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.propertyFavorite(id),
    );
    return Property.fromJson(response.data!);
  }

  @override
  Future<List<Property>> fetchFavorites() async {
    // page_size élevé : l'écran Favoris affiche la liste complète, sans
    // pagination (comportement identique au mock).
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.properties,
      query: {'favorites_only': true, 'page_size': 100},
    );
    return _parsePage(response.data!).results;
  }

  @override
  Future<Property> addProperty(Property property) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.properties,
      data: property.toJson(),
    );
    if (response.data == null) {
      throw const UnknownApiException('La propriété a été créée mais la réponse est vide.');
    }
    return Property.fromJson(response.data!);
  }

  @override
  Future<List<Property>> fetchMyProperties() async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      ApiEndpoints.myProperties,
      query: {'page_size': 100},
    );
    return _parsePage(response.data!).results;
  }

  @override
  Future<Property> updateProperty(String id, Map<String, dynamic> changes) async {
    final response = await _apiClient.patch<Map<String, dynamic>>(
      ApiEndpoints.propertyDetail(id),
      data: changes,
    );
    return Property.fromJson(response.data!);
  }

  @override
  Future<void> deleteProperty(String id) async {
    await _apiClient.delete<void>(ApiEndpoints.propertyDetail(id));
  }

  @override
  Future<Property> uploadImage(String propertyId, XFile file, {bool isCover = false}) async {
    final formData = FormData.fromMap({
      'is_cover': isCover,
      'image': await MultipartFile.fromFile(file.path, filename: file.name),
    });
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.propertyUploadImage(propertyId),
      data: formData,
    );
    if (response.data == null) {
      throw const UnknownApiException('La photo a été envoyée mais la réponse est vide.');
    }
    return Property.fromJson(response.data!);
  }

  @override
  Future<Property> deleteImage(String propertyId, String url) async {
    final response = await _apiClient.delete<Map<String, dynamic>>(
      ApiEndpoints.propertyUploadImage(propertyId),
      data: {'url': url},
    );
    if (response.data == null) {
      throw const UnknownApiException('La photo a été supprimée mais la réponse est vide.');
    }
    return Property.fromJson(response.data!);
  }

  @override
  Future<Property> incrementView(String id) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      ApiEndpoints.propertyView(id),
    );
    return Property.fromJson(response.data!);
  }
}
