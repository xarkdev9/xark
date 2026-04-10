/// Currency symbol map for common currencies.
const Map<String, String> _currencySymbols = {
  'USD': '\$',
  'EUR': '\u20AC',
  'GBP': '\u00A3',
  'CHF': 'CHF',
  'INR': '\u20B9',
  'JPY': '\u00A5',
  'CNY': '\u00A5',
  'KRW': '\u20A9',
  'AUD': 'A\$',
  'CAD': 'C\$',
  'SGD': 'S\$',
  'HKD': 'HK\$',
  'NZD': 'NZ\$',
  'SEK': 'kr',
  'NOK': 'kr',
  'DKK': 'kr',
  'MXN': 'MX\$',
  'BRL': 'R\$',
  'ZAR': 'R',
  'THB': '\u0E3F',
  'TWD': 'NT\$',
  'PLN': 'z\u0142',
  'TRY': '\u20BA',
  'RUB': '\u20BD',
  'ILS': '\u20AA',
  'AED': 'AED',
  'SAR': 'SAR',
  'MYR': 'RM',
  'IDR': 'Rp',
  'PHP': '\u20B1',
  'VND': '\u20AB',
};

/// Whether this currency places the symbol before the amount.
bool _isPrefix(String currency) {
  // Currencies with post-fix symbols or space-separated codes.
  const postfix = {'CHF', 'SEK', 'NOK', 'DKK', 'AED', 'SAR'};
  return !postfix.contains(currency);
}

/// Formats [amount] with the appropriate currency symbol.
///
/// Examples:
/// - `formatCurrency(142.50, 'USD')` -> `"\$142.50"`
/// - `formatCurrency(142.50, 'EUR')` -> `"\u20AC142.50"`
/// - `formatCurrency(142.50, 'CHF')` -> `"CHF 142.50"`
/// - `formatCurrency(1000, 'JPY')` -> `"\u00A51000"` (no decimals)
String formatCurrency(double amount, String currency) {
  final symbol = _currencySymbols[currency] ?? currency;
  final isZeroDecimal = currency == 'JPY' || currency == 'KRW' || currency == 'VND';
  final formatted = isZeroDecimal
      ? amount.toInt().toString()
      : amount.toStringAsFixed(2);

  if (_isPrefix(currency)) {
    return '$symbol$formatted';
  }
  return '$symbol $formatted';
}

/// Formats a [DateTime] as "Jul 8, 2026".
String formatDate(DateTime date) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

/// Formats a balance with sign prefix.
///
/// Examples:
/// - `formatBalanceSign(142.50, 'USD')` -> `"+\$142.50"`
/// - `formatBalanceSign(-142.50, 'USD')` -> `"-\$142.50"`
/// - `formatBalanceSign(0, 'USD')` -> `"\$0.00"`
String formatBalanceSign(double balance, String currency) {
  if (balance == 0) return formatCurrency(0, currency);
  final sign = balance > 0 ? '+' : '-';
  return '$sign${formatCurrency(balance.abs(), currency)}';
}
