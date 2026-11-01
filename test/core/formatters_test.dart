import 'package:flutter_test/flutter_test.dart';
import 'package:louemoi/core/utils/formatters.dart';

void main() {
  group('Formatters', () {
    test('price formats CFA currency with dot separators', () {
      expect(Formatters.price(5000), '5.000Fcfa');
      expect(Formatters.price(150000), '150.000Fcfa');
    });

    test('relativeTime formats short differences correctly', () {
      final now = DateTime.now();
      expect(Formatters.relativeTime(now), "à l'instant");
      expect(
        Formatters.relativeTime(now.subtract(const Duration(minutes: 5))),
        '5min',
      );
      expect(
        Formatters.relativeTime(now.subtract(const Duration(hours: 3))),
        '3h',
      );
      expect(
        Formatters.relativeTime(now.subtract(const Duration(days: 2))),
        '2j',
      );
    });

    test('relativeTimeWithPrefix handles just now and older dates correctly', () {
      final now = DateTime.now();
      // Moins d'une minute -> "À l'instant" (sans "Il y a à l'instant")
      expect(Formatters.relativeTimeWithPrefix(now), "À l'instant");

      // 10 minutes -> "Il y a 10min"
      expect(
        Formatters.relativeTimeWithPrefix(
          now.subtract(const Duration(minutes: 10)),
        ),
        'Il y a 10min',
      );

      // 2 heures -> "Il y a 2h"
      expect(
        Formatters.relativeTimeWithPrefix(
          now.subtract(const Duration(hours: 2)),
        ),
        'Il y a 2h',
      );
    });
  });
}

