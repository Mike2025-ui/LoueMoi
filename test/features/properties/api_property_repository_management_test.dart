import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:louemoi/core/network/api_client.dart';
import 'package:louemoi/core/network/api_exceptions.dart';
import 'package:louemoi/features/properties/data/api_property_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

Response<Map<String, dynamic>> _fakeResponse(Map<String, dynamic> data) {
  return Response(data: data, requestOptions: RequestOptions(path: '/'));
}

Map<String, dynamic> _propertyJson({required int id, List<String> images = const []}) {
  return {
    'id': id,
    'title': 'Bien test',
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
    'is_favorite': false,
    'images': images,
    'cover_image': images.isNotEmpty ? images.first : '',
    'features': <String>[],
    'amenities': <String>[],
    'agent': {
      'id': 1,
      'first_name': 'Agent',
      'last_name': 'Test',
      'phone': '0700000000',
      'whatsapp': '0700000000',
      'is_verified': true,
      'rating': 4.8,
    },
    'views_count': 0,
    'favorites_count': 0,
    'created_at': '2026-01-01T00:00:00Z',
    'updated_at': '2026-01-01T00:00:00Z',
  };
}

void main() {
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(FormData());
  });

  late MockApiClient apiClient;
  late ApiPropertyRepository repository;

  setUp(() {
    apiClient = MockApiClient();
    repository = ApiPropertyRepository(apiClient);
  });

  test('updateProperty PATCHes /api/properties/{id}/ and parses the response', () async {
    when(() => apiClient.patch<Map<String, dynamic>>(any(), data: any(named: 'data')))
        .thenAnswer((_) async => _fakeResponse(_propertyJson(id: 5)));

    final property = await repository.updateProperty('5', {'title': 'Modifie'});

    expect(property.id, '5');
    final call = verify(
      () => apiClient.patch<Map<String, dynamic>>(captureAny(), data: captureAny(named: 'data')),
    ).captured;
    expect(call.first, '/api/properties/5/');
    expect(call[1], {'title': 'Modifie'});
  });

  test('deleteProperty DELETEs /api/properties/{id}/', () async {
    when(() => apiClient.delete<void>(any())).thenAnswer((_) async => _fakeResponse({}));

    await repository.deleteProperty('7');

    verify(() => apiClient.delete<void>('/api/properties/7/')).called(1);
  });

  test('uploadImage posts multipart FormData to the upload-image action', () async {
    final tempFile = File('${Directory.systemTemp.path}/louemoi_test_upload.jpg');
    await tempFile.writeAsBytes([0, 1, 2, 3]);
    addTearDown(() => tempFile.delete());

    when(() => apiClient.post<Map<String, dynamic>>(any(), data: any(named: 'data')))
        .thenAnswer((_) async => _fakeResponse(_propertyJson(id: 9, images: ['http://x/1.jpg'])));

    final property = await repository.uploadImage('9', XFile(tempFile.path), isCover: true);

    expect(property.images, ['http://x/1.jpg']);
    final call = verify(
      () => apiClient.post<Map<String, dynamic>>(captureAny(), data: captureAny(named: 'data')),
    ).captured;
    expect(call.first, '/api/properties/9/upload-image/');
    expect(call[1], isA<FormData>());
  });

  test('deleteImage sends the URL to remove and parses the updated property', () async {
    when(() => apiClient.delete<Map<String, dynamic>>(any(), data: any(named: 'data')))
        .thenAnswer((_) async => _fakeResponse(_propertyJson(id: 9, images: const [])));

    final property = await repository.deleteImage('9', 'http://x/1.jpg');

    expect(property.images, isEmpty);
    final call = verify(
      () => apiClient.delete<Map<String, dynamic>>(
        captureAny(),
        data: captureAny(named: 'data'),
      ),
    ).captured;
    expect(call.first, '/api/properties/9/upload-image/');
    expect(call[1], {'url': 'http://x/1.jpg'});
  });

  test('incrementView posts to the view action', () async {
    when(() => apiClient.post<Map<String, dynamic>>(any()))
        .thenAnswer((_) async => _fakeResponse(_propertyJson(id: 2)));

    await repository.incrementView('2');

    verify(() => apiClient.post<Map<String, dynamic>>('/api/properties/2/view/')).called(1);
  });

  test('fetchMyProperties requests /api/agent/properties/', () async {
    when(() => apiClient.get<Map<String, dynamic>>(any(), query: any(named: 'query')))
        .thenAnswer((_) async => _fakeResponse({
              'count': 1,
              'next': null,
              'previous': null,
              'results': [_propertyJson(id: 4)],
            }));

    final properties = await repository.fetchMyProperties();

    expect(properties, hasLength(1));
    verify(() => apiClient.get<Map<String, dynamic>>(
          '/api/agent/properties/',
          query: any(named: 'query'),
        )).called(1);
  });

  test('updateProperty propagates a ForbiddenException instead of swallowing it', () async {
    when(() => apiClient.patch<Map<String, dynamic>>(any(), data: any(named: 'data')))
        .thenThrow(const ForbiddenException("Vous n'êtes pas le propriétaire de cette annonce."));

    expect(
      () => repository.updateProperty('99', {'title': 'x'}),
      throwsA(isA<ForbiddenException>()),
    );
  });
}
