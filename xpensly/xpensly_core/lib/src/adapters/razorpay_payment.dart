import '../ports/payment_provider.dart';

/// Placeholder payment adapter for Razorpay.
///
/// Razorpay's actual payment flow requires server-side order creation via
/// their API. This adapter generates a placeholder URL that encodes the
/// amount (in paise) and currency as query parameters for demonstration
/// and testing purposes. Razorpay supports QR-based payments, so
/// [generateQrData] returns the same link string.
class RazorpayPayment implements XpenslyPaymentProvider {
  /// Creates a Razorpay payment adapter.
  const RazorpayPayment();

  @override
  String get name => 'razorpay';

  @override
  bool get supportsQr => true;

  @override
  String generateLink({
    required String from,
    required String to,
    required double amount,
    required String currency,
    String? note,
  }) {
    final amountPaise = (amount * 100).toInt();
    return 'https://rzp.io/pay?amount=$amountPaise&currency=$currency';
  }

  @override
  String? generateQrData({
    required String from,
    required String to,
    required double amount,
    required String currency,
    String? note,
  }) {
    // Razorpay supports QR-based payments using the same link.
    return generateLink(
      from: from,
      to: to,
      amount: amount,
      currency: currency,
      note: note,
    );
  }
}
