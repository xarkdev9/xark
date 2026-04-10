import '../ports/payment_provider.dart';

/// Payment adapter for PayPal.
///
/// Generates `paypal.me` links that open a PayPal payment page with
/// pre-filled recipient and amount. QR code generation is not supported.
class PaypalPayment implements XpenslyPaymentProvider {
  /// Creates a PayPal payment adapter.
  const PaypalPayment();

  @override
  String get name => 'paypal';

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
    final encodedTo = Uri.encodeComponent(to);
    return 'https://paypal.me/$encodedTo/$amount$currency';
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
