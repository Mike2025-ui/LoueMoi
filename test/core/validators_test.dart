import 'package:flutter_test/flutter_test.dart';
import 'package:louemoi/core/utils/validators.dart';

void main() {
  group('Validators.phone', () {
    test('rejects empty value', () {
      expect(Validators.phone(''), isNotNull);
    });

    test('rejects too short numbers', () {
      expect(Validators.phone('123'), isNotNull);
    });

    test('accepts a valid phone number', () {
      expect(Validators.phone('0700000000'), isNull);
    });
  });

  group('Validators.password', () {
    test('rejects short passwords', () {
      expect(Validators.password('123'), isNotNull);
    });

    test('accepts passwords with 6+ chars', () {
      expect(Validators.password('secret1'), isNull);
    });
  });

  group('Validators.confirmPassword', () {
    test('rejects mismatched confirmation', () {
      expect(Validators.confirmPassword('abcdef', 'ghijkl'), isNotNull);
    });

    test('accepts matching confirmation', () {
      expect(Validators.confirmPassword('abcdef', 'abcdef'), isNull);
    });
  });
}
