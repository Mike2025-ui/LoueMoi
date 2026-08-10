import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:louemoi/core/services/location_permission_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockGeolocatorPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements GeolocatorPlatform {}

Position _fakePosition({double latitude = 5.35, double longitude = -4.0}) {
  return Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: DateTime(2026, 1, 1),
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(const LocationSettings());
  });

  late MockGeolocatorPlatform mockPlatform;
  late LocationPermissionService service;

  setUp(() {
    mockPlatform = MockGeolocatorPlatform();
    GeolocatorPlatform.instance = mockPlatform;
    service = const LocationPermissionService();
  });

  test('returns success with coordinates when permission is already granted', () async {
    when(() => mockPlatform.isLocationServiceEnabled()).thenAnswer((_) async => true);
    when(() => mockPlatform.checkPermission())
        .thenAnswer((_) async => LocationPermission.whileInUse);
    when(() => mockPlatform.getCurrentPosition(locationSettings: any(named: 'locationSettings')))
        .thenAnswer((_) async => _fakePosition());

    final result = await service.getCurrentPosition();

    expect(result.isSuccess, isTrue);
    expect(result.latitude, 5.35);
    expect(result.longitude, -4.0);
  });

  test('returns serviceDisabled without requesting permission when GPS is off', () async {
    when(() => mockPlatform.isLocationServiceEnabled()).thenAnswer((_) async => false);

    final result = await service.getCurrentPosition();

    expect(result.status, LocationResultStatus.serviceDisabled);
    expect(result.message, isNotNull);
    expect(result.isSuccess, isFalse);
    verifyNever(() => mockPlatform.checkPermission());
  });

  test('requests permission when initially denied, then succeeds once granted', () async {
    when(() => mockPlatform.isLocationServiceEnabled()).thenAnswer((_) async => true);
    when(() => mockPlatform.checkPermission()).thenAnswer((_) async => LocationPermission.denied);
    when(() => mockPlatform.requestPermission())
        .thenAnswer((_) async => LocationPermission.whileInUse);
    when(() => mockPlatform.getCurrentPosition(locationSettings: any(named: 'locationSettings')))
        .thenAnswer((_) async => _fakePosition());

    final result = await service.getCurrentPosition();

    expect(result.isSuccess, isTrue);
    verify(() => mockPlatform.requestPermission()).called(1);
  });

  test('returns permissionDenied (in French) when the user refuses', () async {
    when(() => mockPlatform.isLocationServiceEnabled()).thenAnswer((_) async => true);
    when(() => mockPlatform.checkPermission()).thenAnswer((_) async => LocationPermission.denied);
    when(() => mockPlatform.requestPermission()).thenAnswer((_) async => LocationPermission.denied);

    final result = await service.getCurrentPosition();

    expect(result.status, LocationResultStatus.permissionDenied);
    expect(result.message, contains('Autorisez'));
  });

  test('returns permissionDeniedForever without ever calling getCurrentPosition', () async {
    when(() => mockPlatform.isLocationServiceEnabled()).thenAnswer((_) async => true);
    when(() => mockPlatform.checkPermission())
        .thenAnswer((_) async => LocationPermission.deniedForever);

    final result = await service.getCurrentPosition();

    expect(result.status, LocationResultStatus.permissionDeniedForever);
    verifyNever(
      () => mockPlatform.getCurrentPosition(locationSettings: any(named: 'locationSettings')),
    );
  });

  test('never throws: a platform failure becomes a LocationResult.error', () async {
    when(() => mockPlatform.isLocationServiceEnabled()).thenThrow(Exception('boom'));

    final result = await service.getCurrentPosition();

    expect(result.status, LocationResultStatus.error);
    expect(result.isSuccess, isFalse);
  });
}
