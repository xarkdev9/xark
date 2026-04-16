import 'package:test/test.dart';
import 'package:xpensly_core/xpensly_core.dart';

void main() {
  final converter = CurrencyConverter();

  // Rates relative to EUR as base.
  final rates = {
    'EUR': 1.0,
    'USD': 1.08,
    'CHF': 0.94,
    'GBP': 0.86,
  };

  group('CurrencyConverter', () {
    test('same currency → no conversion', () {
      final result = converter.convert(100, 'EUR', 'EUR', rates);
      expect(result, closeTo(100, 0.01));
    });

    test('EUR→CHF with rate 0.94 → correct result', () {
      // EUR→CHF: 100 * (0.94 / 1.0) = 94.0
      final result = converter.convert(100, 'EUR', 'CHF', rates);
      expect(result, closeTo(94, 0.01));
    });

    test('USD→EUR conversion', () {
      // USD→EUR: 100 * (1.0 / 1.08) ≈ 92.59
      final result = converter.convert(100, 'USD', 'EUR', rates);
      expect(result, closeTo(92.59, 0.01));
    });

    test('missing rate → throws ArgumentError', () {
      expect(
        () => converter.convert(100, 'EUR', 'JPY', rates),
        throwsArgumentError,
      );
      expect(
        () => converter.convert(100, 'JPY', 'EUR', rates),
        throwsArgumentError,
      );
    });

    test('round-trip: USD→EUR→USD preserves value (within rounding)', () {
      final toEur = converter.convert(100, 'USD', 'EUR', rates);
      final backToUsd = converter.convert(toEur, 'EUR', 'USD', rates);
      expect(backToUsd, closeTo(100, 0.05));
    });
  });
}
