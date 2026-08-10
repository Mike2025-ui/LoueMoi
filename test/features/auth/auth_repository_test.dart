import 'package:flutter_test/flutter_test.dart';
import 'package:louemoi/features/auth/data/auth_repository.dart';
import 'package:louemoi/features/auth/models/user_role.dart';

void main() {
  group('MockAuthRepository.login', () {
    final repository = MockAuthRepository();

    test('succeeds with non-empty credentials', () async {
      final user = await repository.login(phone: '0700000000', password: 'secret1');
      expect(user.phone, '0700000000');
      expect(user.token, isNotNull);
    });

    test('rejects an empty password', () async {
      expect(
        () => repository.login(phone: '0700000000', password: ''),
        throwsException,
      );
    });
  });

  group('MockAuthRepository.register', () {
    test('returns a client user by default', () async {
      final repository = MockAuthRepository();
      final user = await repository.register(
        firstName: 'Jean',
        lastName: 'Kouassi',
        phone: '0700000000',
        password: 'secret1',
        role: UserRole.client,
      );
      expect(user.fullName, 'Jean Kouassi');
      expect(user.role, UserRole.client);
      expect(user.isAgent, isFalse);
      expect(user.agentProfile, isNull);
    });

    test('returns an agent user with an (unverified) agent profile when role=agent',
        () async {
      final repository = MockAuthRepository();
      final user = await repository.register(
        firstName: 'Mme',
        lastName: 'Kouakou',
        phone: '0700000001',
        password: 'secret1',
        role: UserRole.agent,
      );
      expect(user.role, UserRole.agent);
      expect(user.isAgent, isTrue);
      expect(user.agentProfile, isNotNull);
      // Un agent ne peut jamais s'auto-vérifier — même côté mock.
      expect(user.agentProfile!.isVerified, isFalse);
    });
  });
}
