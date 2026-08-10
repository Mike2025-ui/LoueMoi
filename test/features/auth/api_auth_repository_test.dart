import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louemoi/core/network/api_client.dart';
import 'package:louemoi/core/services/auth_storage.dart';
import 'package:louemoi/features/auth/data/api_auth_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockApiClient extends Mock implements ApiClient {}

class MockAuthStorage extends Mock implements AuthStorage {}

Response<Map<String, dynamic>> _fakeResponse(Map<String, dynamic> data) {
  return Response(data: data, requestOptions: RequestOptions(path: '/'));
}

void main() {
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  late MockApiClient apiClient;
  late MockAuthStorage authStorage;
  late ApiAuthRepository repository;

  setUp(() {
    apiClient = MockApiClient();
    authStorage = MockAuthStorage();
    repository = ApiAuthRepository(apiClient, authStorage);
    when(
      () => authStorage.saveTokens(
        access: any(named: 'access'),
        refresh: any(named: 'refresh'),
      ),
    ).thenAnswer((_) async {});
  });

  test('login persists access/refresh tokens and returns the parsed user', () async {
    when(() => apiClient.post<Map<String, dynamic>>(any(), data: any(named: 'data')))
        .thenAnswer((_) async => _fakeResponse({
              'id': 1,
              'first_name': 'Jean',
              'last_name': 'Kouassi',
              'phone': '0700000000',
              'whatsapp': '0700000000',
              'token': 'access-123',
              'refresh': 'refresh-456',
            }));

    final user = await repository.login(phone: '0700000000', password: 'secret1');

    expect(user.fullName, 'Jean Kouassi');
    verify(() => authStorage.saveTokens(access: 'access-123', refresh: 'refresh-456'))
        .called(1);
  });

  test('restoreSession returns null without hitting the network when no token is stored',
      () async {
    when(() => authStorage.getAccessToken()).thenAnswer((_) async => null);

    final user = await repository.restoreSession();

    expect(user, isNull);
    verifyNever(() => apiClient.get<Map<String, dynamic>>(any(), query: any(named: 'query')));
  });
}
