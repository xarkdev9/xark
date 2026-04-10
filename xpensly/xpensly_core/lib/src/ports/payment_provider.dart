/// Abstract interface for generating payment links and QR data.
///
/// Each implementation targets a specific payment provider (e.g., Venmo, UPI,
/// PayPal). The SDK ships with several built-in adapters; consumers can add
/// their own by implementing this interface.
abstract class XpenslyPaymentProvider {
  /// Human-readable identifier for this provider (e.g., "venmo", "upi").
  String get name;

  /// Whether this provider supports QR code generation.
  bool get supportsQr;

  /// Generates a deep-link or web URL that initiates a payment.
  ///
  /// [from] and [to] are provider-specific identifiers (usernames, UPI VPAs,
  /// email addresses, etc.). [amount] is the payment amount in [currency].
  /// An optional [note] may be included as a payment description.
  String generateLink({
    required String from,
    required String to,
    required double amount,
    required String currency,
    String? note,
  });

  /// Generates a string suitable for encoding into a QR code, or `null`
  /// if the provider does not support QR payments.
  ///
  /// Parameters match [generateLink].
  String? generateQrData({
    required String from,
    required String to,
    required double amount,
    required String currency,
    String? note,
  });
}
