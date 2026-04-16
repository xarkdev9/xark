import '../ports/rate_provider.dart';

/// A rate provider backed by a fixed, immutable map of exchange rates.
///
/// Useful for testing, offline scenarios, or when rates are fetched once
/// and cached for the duration of a session.
///
/// ```dart
/// final rates = FixedRateProvider({
///   'EUR': 0.92,
///   'GBP': 0.79,
///   'INR': 83.12,
/// });
/// final result = await rates.fetchRates('USD', ['EUR', 'GBP']);
/// // { 'EUR': 0.92, 'GBP': 0.79 }
/// ```
class FixedRateProvider implements XpenslyRateProvider {
  final Map<String, double> _rates;

  /// Creates a fixed rate provider from the given [rates] map.
  ///
  /// Keys are ISO 4217 currency codes; values are the exchange rate
  /// relative to the base currency that will be passed to [fetchRates].
  const FixedRateProvider(this._rates);

  @override
  Future<Map<String, double>> fetchRates(
    String baseCurrency,
    List<String> currencies,
  ) async {
    return Map.fromEntries(
      currencies
          .where((c) => _rates.containsKey(c))
          .map((c) => MapEntry(c, _rates[c]!)),
    );
  }
}
