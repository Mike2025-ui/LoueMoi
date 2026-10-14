import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:louemoi/core/services/fcm_service.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseMessaging extends Mock implements FirebaseMessaging {}

const _fakeSettings = NotificationSettings(
  alert: AppleNotificationSetting.notSupported,
  announcement: AppleNotificationSetting.notSupported,
  authorizationStatus: AuthorizationStatus.authorized,
  badge: AppleNotificationSetting.notSupported,
  carPlay: AppleNotificationSetting.notSupported,
  lockScreen: AppleNotificationSetting.notSupported,
  notificationCenter: AppleNotificationSetting.notSupported,
  showPreviews: AppleShowPreviewSetting.notSupported,
  timeSensitive: AppleNotificationSetting.notSupported,
  criticalAlert: AppleNotificationSetting.notSupported,
  sound: AppleNotificationSetting.notSupported,
  providesAppNotificationSettings: AppleNotificationSetting.notSupported,
);

void main() {
  late MockFirebaseMessaging mockMessaging;
  late FcmService service;

  setUp(() {
    mockMessaging = MockFirebaseMessaging();
    service = FcmService(messaging: mockMessaging);
  });

  test('requests permission then returns the FCM token on success', () async {
    when(() => mockMessaging.requestPermission(
          alert: any(named: 'alert'),
          announcement: any(named: 'announcement'),
          badge: any(named: 'badge'),
          carPlay: any(named: 'carPlay'),
          criticalAlert: any(named: 'criticalAlert'),
          provisional: any(named: 'provisional'),
          sound: any(named: 'sound'),
          providesAppNotificationSettings: any(named: 'providesAppNotificationSettings'),
        )).thenAnswer((_) async => _fakeSettings);
    when(() => mockMessaging.getToken()).thenAnswer((_) async => 'fake-fcm-token');
    when(() => mockMessaging.onTokenRefresh).thenAnswer((_) => const Stream.empty());

    final token = await service.initialize();

    expect(token, 'fake-fcm-token');
    verify(() => mockMessaging.requestPermission(
          alert: any(named: 'alert'),
          announcement: any(named: 'announcement'),
          badge: any(named: 'badge'),
          carPlay: any(named: 'carPlay'),
          criticalAlert: any(named: 'criticalAlert'),
          provisional: any(named: 'provisional'),
          sound: any(named: 'sound'),
          providesAppNotificationSettings: any(named: 'providesAppNotificationSettings'),
        )).called(1);
  });

  test('returns null without throwing when no token is available', () async {
    when(() => mockMessaging.requestPermission(
          alert: any(named: 'alert'),
          announcement: any(named: 'announcement'),
          badge: any(named: 'badge'),
          carPlay: any(named: 'carPlay'),
          criticalAlert: any(named: 'criticalAlert'),
          provisional: any(named: 'provisional'),
          sound: any(named: 'sound'),
          providesAppNotificationSettings: any(named: 'providesAppNotificationSettings'),
        )).thenAnswer((_) async => _fakeSettings);
    when(() => mockMessaging.getToken()).thenAnswer((_) async => null);
    when(() => mockMessaging.onTokenRefresh).thenAnswer((_) => const Stream.empty());

    final token = await service.initialize();

    expect(token, isNull);
  });

  test('never throws: a platform failure resolves to null instead of crashing the app', () async {
    when(() => mockMessaging.requestPermission(
          alert: any(named: 'alert'),
          announcement: any(named: 'announcement'),
          badge: any(named: 'badge'),
          carPlay: any(named: 'carPlay'),
          criticalAlert: any(named: 'criticalAlert'),
          provisional: any(named: 'provisional'),
          sound: any(named: 'sound'),
          providesAppNotificationSettings: any(named: 'providesAppNotificationSettings'),
        )).thenThrow(Exception('Firebase misconfigured'));

    final token = await service.initialize();

    expect(token, isNull);
  });

  test('listens to onTokenRefresh without throwing', () async {
    when(() => mockMessaging.requestPermission(
          alert: any(named: 'alert'),
          announcement: any(named: 'announcement'),
          badge: any(named: 'badge'),
          carPlay: any(named: 'carPlay'),
          criticalAlert: any(named: 'criticalAlert'),
          provisional: any(named: 'provisional'),
          sound: any(named: 'sound'),
          providesAppNotificationSettings: any(named: 'providesAppNotificationSettings'),
        )).thenAnswer((_) async => _fakeSettings);
    when(() => mockMessaging.getToken()).thenAnswer((_) async => 'fake-fcm-token');
    when(() => mockMessaging.onTokenRefresh)
        .thenAnswer((_) => Stream.value('refreshed-token'));

    await service.initialize();

    verify(() => mockMessaging.onTokenRefresh).called(1);
  });
}
