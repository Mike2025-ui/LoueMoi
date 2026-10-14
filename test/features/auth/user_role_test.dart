import 'package:flutter_test/flutter_test.dart';
import 'package:louemoi/features/auth/models/user.dart';
import 'package:louemoi/features/auth/models/user_role.dart';

void main() {
  group('UserRole.fromString', () {
    test('parses "client"', () {
      expect(UserRole.fromString('client'), UserRole.client);
    });

    test('parses "agent"', () {
      expect(UserRole.fromString('agent'), UserRole.agent);
    });

    test('parses "bailleur"', () {
      expect(UserRole.fromString('bailleur'), UserRole.bailleur);
    });

    test('falls back to client for "admin" — never a mobile-facing role', () {
      expect(UserRole.fromString('admin'), UserRole.client);
    });

    test('falls back to client for null/unknown values', () {
      expect(UserRole.fromString(null), UserRole.client);
      expect(UserRole.fromString('n_importe_quoi'), UserRole.client);
    });
  });

  group('User.fromJson role/agentProfile parsing', () {
    test('parses a client: no agent_profile', () {
      final user = User.fromJson({
        'id': 1,
        'first_name': 'Jean',
        'last_name': 'Kouassi',
        'phone': '0700000000',
        'whatsapp': '0700000000',
        'role': 'client',
        'agent_profile': null,
      });

      expect(user.role, UserRole.client);
      expect(user.isAgent, isFalse);
      expect(user.agentProfile, isNull);
    });

    test('parses an agent with a nested agent_profile', () {
      final user = User.fromJson({
        'id': 1,
        'first_name': 'Mme Kouakou',
        'last_name': 'Marie Therese Ange',
        'phone': '0700000000',
        'whatsapp': '0700000000',
        'role': 'agent',
        'agent_profile': {
          'agency_name': 'Immo Plus',
          'whatsapp': '0700000000',
          'description': '',
          'is_verified': true,
          'rating': 4.8,
        },
      });

      expect(user.role, UserRole.agent);
      expect(user.isAgent, isTrue);
      expect(user.agentProfile, isNotNull);
      expect(user.agentProfile!.isVerified, isTrue);
      expect(user.agentProfile!.rating, 4.8);
    });

    test('parses a bailleur: no agent_profile, canOwnProperties is true', () {
      final user = User.fromJson({
        'id': 1,
        'first_name': 'Adjoua',
        'last_name': 'N\'Guessan',
        'phone': '0700000000',
        'whatsapp': '0700000000',
        'role': 'bailleur',
        'agent_profile': null,
      });

      expect(user.role, UserRole.bailleur);
      expect(user.isBailleur, isTrue);
      expect(user.isAgent, isFalse);
      expect(user.agentProfile, isNull);
      expect(user.canOwnProperties, isTrue);
    });

    test('canOwnProperties is false for a client', () {
      final user = User.fromJson({
        'id': 1,
        'first_name': 'Jean',
        'last_name': 'Kouassi',
        'phone': '0700000000',
        'whatsapp': '0700000000',
        'role': 'client',
      });

      expect(user.canOwnProperties, isFalse);
    });

    test('missing role key defaults to client (backward-compatible parsing)', () {
      final user = User.fromJson({
        'id': 1,
        'first_name': 'Jean',
        'last_name': 'Kouassi',
        'phone': '0700000000',
        'whatsapp': '0700000000',
      });

      expect(user.role, UserRole.client);
    });
  });
}
