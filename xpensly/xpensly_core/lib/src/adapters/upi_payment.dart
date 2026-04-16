import '../ports/payment_provider.dart';

/// Payment adapter for UPI (Unified Payments Interface).
///
/// Generates `upi://pay` URIs compatible with Indian payment apps such as
/// Google Pay, PhonePe, and Paytm. The same URI is used for both deep links
/// and QR code encoding, as the UPI specification encodes all payment data
/// in a single URI.
class UpiPayment implements XpenslyPaymentProvider {
  /// Creates a UPI payment adapter.
  const UpiPayment();

  @override
  String get name => 'upi';

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
    return _buildUri(to: to, amount: amount, currency: currency, note: note);
  }

  @override
  String? generateQrData({
    required String from,
    required String to,
    required double amount,
    required String currency,
    String? note,
  }) {
    // UPI QR codes encode the same URI as the deep link.
    return _buildUri(to: to, amount: amount, currency: currency, note: note);
  }

  String _buildUri({
    required String to,
    required double amount,
    required String currency,
    String? note,
  }) {
    final encodedTo = Uri.encodeComponent(to);
    final encodedNote = Uri.encodeComponent(note ?? 'Xpensly settle');
    return 'upi://pay?pa=$encodedTo&pn=$encodedTo'
        '&am=$amount&tn=$encodedNote&cu=$currency';
  }
}
