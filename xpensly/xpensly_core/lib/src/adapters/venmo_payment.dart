import '../ports/payment_provider.dart';

/// Payment adapter for Venmo.
///
/// Generates `venmo://` deep links that open the Venmo app with pre-filled
/// payment details. QR code generation is not supported.
class VenmoPayment implements XpenslyPaymentProvider {
  /// Creates a Venmo payment adapter.
  const VenmoPayment();

  @override
  String get name => 'venmo';

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
    final encodedNote = Uri.encodeComponent(note ?? 'Xpensly settle');
    return 'venmo://paycharge?txn=pay&recipients=$encodedTo'
        '&amount=$amount&note=$encodedNote';
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
