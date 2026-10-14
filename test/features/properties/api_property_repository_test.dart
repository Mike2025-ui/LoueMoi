import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louemoi/core/network/api_client.dart';
import 'package:louemoi/features/filters/models/filter_params.dart';
import 'package:louemoi/features/properties/data/api_property_repository.dart';
import 'package:louemoi/features/properties/models/property_enums.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

Response<Map<String, dynamic>> _fakeResponse(Map<String, dynamic> data) {
  return Response(data: data, requestOptions: RequestOptions(path: '/'));
}

Map<String, dynamic> _propertyJson({required int id, bool isFavorite = false}) {
  return {
    'id': id,
    'title': 'Appartement test',
    'description': '',
    'type': 'logement',
    'category': 'Studio',
    'transaction_type': 'location',
    'price': 100000,
    'deposit': null,
    'advance': null,
    'city': 'Abidjan',
    'commune': 'Cocody',
    'district': 'Vallon',
    'address': '',
    'latitude': null,
    'longitude': null,
    'status': 'disponible',
    'is_future': false,
    'is_favorite': isFavorite,
    'images': <String>[],
    'cover_image': '',
    'features': <String>[],
    'amenities': <String>[],
    'agent': {
      'id': 1,
      'first_name': 'Mme Kouakou',
      'last_name': 'Marie Therese Ange',
      'phone': '0700000000',
      'whatsapp': '0700000000',
      'is_verified': true,
      'rating': 4.8,
    },
    'created_at': '2026-01-01T00:00:00Z',
    'updated_at': '2026-01-01T00:00:00Z',
  };
}

void main() {
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  late MockApiClient apiClient;
  late ApiPropertyRepository repository;

  setUp(() {
    apiClient = MockApiClient();
    repository = ApiPropertyRepository(apiClient);
  });

  group('fetchProperties', () {
    test('parses a paginated Django response and reports hasMore from next', () async {
      when(() => apiClient.get<Map<String, dynamic>>(any(), query: any(named: 'query')))
          .thenAnswer((_) async => _fakeResponse({
                'count': 2,
                'next': 'http://api/properties/?page=2',
                'previous': null,
                'results': [_propertyJson(id: 1)],
              }));

      final page = await repository.fetchProperties(filters: const FilterParams(), page: 1);

      expect(page.results, hasLength(1));
      expect(page.results.first.id, '1');
      expect(page.hasMore, isTrue);
      expect(page.count, 2);
    });

    test('reports hasMore false when next is null', () async {
      when(() => apiClient.get<Map<String, dynamic>>(any(), query: any(named: 'query')))
          .thenAnswer((_) async => _fakeResponse({
                'count': 1,
                'next': null,
                'previous': null,
                'results': [_propertyJson(id: 1)],
              }));

      final page = await repository.fetchProperties();

      expect(page.hasMore, isFalse);
    });

    test('maps FilterParams to the Django query parameters', () async {
      when(() => apiClient.get<Map<String, dynamic>>(any(), query: any(named: 'query')))
          .thenAnswer((_) async => _fakeResponse({
                'count': 0,
                'next': null,
                'previous': null,
                'results': [],
              }));

      await repository.fetchProperties(
        filters: const FilterParams(
          transactionType: TransactionType.vente,
          propertyType: PropertyType.terrain,
          commune: 'Cocody',
          district: 'Angre',
          category: 'Villa',
          isFuture: true,
          budgetMin: 1000,
          budgetMax: 5000,
        ),
        page: 2,
      );

      final captured = verify(
        () => apiClient.get<Map<String, dynamic>>(any(), query: captureAny(named: 'query')),
      ).captured.single as Map<String, dynamic>;

      expect(captured['transaction_type'], 'vente');
      expect(captured['type'], 'terrain');
      expect(captured['commune'], 'Cocody');
      expect(captured['district'], 'Angre');
      expect(captured['category'], 'Villa');
      expect(captured['is_future'], true);
      expect(captured['budget_min'], 1000);
      expect(captured['budget_max'], 5000);
      expect(captured['page'], 2);
    });

    test('omits commune/district/category when empty, and budget when unset', () async {
      when(() => apiClient.get<Map<String, dynamic>>(any(), query: any(named: 'query')))
          .thenAnswer((_) async => _fakeResponse({
                'count': 0,
                'next': null,
                'previous': null,
                'results': [],
              }));

      await repository.fetchProperties(filters: const FilterParams(), page: 1);

      final captured = verify(
        () => apiClient.get<Map<String, dynamic>>(any(), query: captureAny(named: 'query')),
      ).captured.single as Map<String, dynamic>;

      expect(captured.containsKey('commune'), isFalse);
      expect(captured.containsKey('district'), isFalse);
      expect(captured.containsKey('category'), isFalse);
      expect(captured.containsKey('budget_min'), isFalse);
      expect(captured.containsKey('budget_max'), isFalse);
      expect(captured.containsKey('is_future'), isFalse);
    });
  });

  test('toggleFavorite returns the property with the updated favorite flag', () async {
    when(() => apiClient.post<Map<String, dynamic>>(any()))
        .thenAnswer((_) async => _fakeResponse(_propertyJson(id: 3, isFavorite: true)));

    final property = await repository.toggleFavorite('3');

    expect(property.isFavorite, isTrue);
  });
}
