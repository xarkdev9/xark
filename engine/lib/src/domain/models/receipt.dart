import 'package:freezed_annotation/freezed_annotation.dart';

part 'receipt.freezed.dart';
part 'receipt.g.dart';

/// A delivery/read receipt for a message from a specific user's device.
@freezed
class Receipt with _$Receipt {
  /// Creates a [Receipt] instance.
  const factory Receipt({
    required String messageId,
    required String userId,
    required String deviceId,
    DateTime? deliveredAt,
    DateTime? readAt,
  }) = _Receipt;

  /// Deserializes from JSON.
  factory Receipt.fromJson(Map<String, dynamic> json) =>
      _$ReceiptFromJson(json);
}
