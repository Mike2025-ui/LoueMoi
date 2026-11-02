import 'package:flutter_test/flutter_test.dart';
import 'package:louemoi/features/auth/models/user.dart';
import 'package:louemoi/features/auth/models/user_role.dart';

void main() {
  group('User.fromJson Robustness Tests', () {
    test('handles missing or null name and phone gracefully without TypeError', () {
      final json = <String, dynamic>{
        'id': '10',
        'first_name': null,
        'last_name': null,
        'phone': null,
        'role': 'client',
      };

      final user = User.fromJson(json);
      expect(user.id, equals('10'));
      expect(user.firstName, isEmpty);
      expect(user.lastName, isEmpty);
      expect(user.phone, isEmpty);
      expect(user.role, equals(UserRole.client));
    });

    test('handles integer boolean flags for is_approved, is_staff, is_superuser', () {
      final json = <String, dynamic>{
        'id': 12,
        'first_name': 'Amadou',
        'last_name': 'Diallo',
        'phone': '0102030405',
        'is_approved': 1,
        'is_staff': 0,
        'is_superuser': 1,
        'is_verified': 1,
        'has_active_subscription': 0,
        'activation_requested': 1,
      };

      final user = User.fromJson(json);
      expect(user.id, equals('12'));
      expect(user.isApproved, isTrue);
      expect(user.isStaff, isFalse);
      expect(user.isSuperAdmin, isTrue);
      expect(user.isVerified, isTrue);
      expect(user.hasActiveSubscription, isFalse);
      expect(user.activationRequested, isTrue);
    });

    test('handles untyped agent_profile map', () {
      final dynamic untypedProfile = <dynamic, dynamic>{
        'id': 5,
        'agency_name': 'Agence Plateau',
        'phone': '0700000000',
        'whatsapp': '0700000000',
        'description': 'Top agence',
        'is_verified': 1,
      };

      final json = <String, dynamic>{
        'id': '99',
        'first_name': 'Koffi',
        'last_name': 'Jean',
        'phone': '0700000000',
        'role': 'agent',
        'agent_profile': untypedProfile,
      };

      final user = User.fromJson(json);
      expect(user.agentProfile, isNotNull);
      expect(user.agentProfile!.agencyName, equals('Agence Plateau'));
    });
  });
}

