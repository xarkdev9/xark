import '../ports/payment_provider.dart';

/// Placeholder payment adapter for Stripe.
///
/// Stripe does not expose a public deep-link protocol for peer-to-peer
/// payments. Real Stripe integration requires server-side session creation
/// via the Stripe API, which returns a unique checkout URL. This adapter
/// generates a placeholder URL that encodes the amount and currency as
/// query parameters for demonstration and testing purposes only.
class StripePayment implements XpenslyPaymentProvider {
  /// Creates a Stripe payment adapter.
  const StripePayment();

  @override
  String get name => 'stripe';

  @override
  bool get supportsQr => false;

  @override
  String generateLink({
    required String from,
    required String to,
    required double amount,
    required String currency,
    String? note,
  }) {
    final baseUrl = const String.fromEnvironment('API_URL', defaultValue: 'https://xark.vercel.app');
    final queryParams = <String, String>{
      'provider': 'stripe',
      'from': from,
      'to': to,
      'amount': amount.toString(),
      'currency': currency,
      if (note != null) 'note': note,
    };
    
    final uri = Uri.parse('$baseUrl/api/xpensly/checkout').replace(queryParameters: queryParams);
    return uri.toString();
  }

  @override
  String? generateQrData({
    required String from,
    required String to,
    required double amount,
    required String currency,
    String? note,
  }) {
    return null;
  }
}
