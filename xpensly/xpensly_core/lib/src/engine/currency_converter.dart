/// Converts monetary amounts between currencies using exchange rates.
///
/// Rates are expressed relative to a common base (e.g., all rates
/// relative to EUR: {"EUR": 1.0, "USD": 1.08, "GBP": 0.86}).
/// Conversion formula: `amount * (toRate / fromRate)`.
class CurrencyConverter {
  /// Converts [amount] from currency [from] to currency [to] using
  /// the provided exchange [rates] map.
  ///
  /// If [from] and [to] are the same currency, returns [amount] unchanged.
  /// Throws [ArgumentError] if either currency code is missing from [rates].
  /// Result is rounded to 2 decimal places.
  double convert(
    double amount,
    String from,
    String to,
    Map<String, double> rates,
  ) {
    if (from == to) return amount;

    if (!rates.containsKey(from)) {
      throw ArgumentError(
          'Exchange rate missing for source currency: $from');
    }
    if (!rates.containsKey(to)) {
      throw ArgumentError(
          'Exchange rate missing for target currency: $to');
    }

    final fromRate = rates[from]!;
    final toRate = rates[to]!;

    if (fromRate == 0) {
      throw ArgumentError(
          'Exchange rate for $from must not be zero.');
    }

    final converted = amount * (toRate / fromRate);
    return _round2(converted);
  }

  double _round2(double value) =>
      (value * 100).roundToDouble() / 100;
}
