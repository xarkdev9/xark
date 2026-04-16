/// Abstract interface for fetching currency exchange rates.
///
/// Implementations may call a live API, read from a cache, or return
/// hard-coded values (see [FixedRateProvider]).
abstract class XpenslyRateProvider {
  /// Returns exchange rates for [currencies] relative to [baseCurrency].
  ///
  /// The returned map contains entries of the form `{ "EUR": 0.92, "GBP": 0.79 }`
  /// where each value represents how much one unit of [baseCurrency] is worth
  /// in the target currency. Currencies not found by the provider may be
  /// omitted from the result.
  Future<Map<String, double>> fetchRates(
    String baseCurrency,
    List<String> currencies,
  );
}
