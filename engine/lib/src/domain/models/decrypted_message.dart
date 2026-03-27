import 'package:freezed_annotation/freezed_annotation.dart';

part 'decrypted_message.freezed.dart';
part 'decrypted_message.g.dart';

/// A link preview extracted from a message, with optional encrypted thumbnail.
@freezed
class LinkPreview with _$LinkPreview {
  /// Creates a [LinkPreview] instance.
  const factory LinkPreview({
    required String url,
    String? title,
    String? description,
    String? mediaUrl,
    String? aesKeyBase64,
    String? ivBase64,
    String? mimeType,
    String? inlineThumbnail,
  }) = _LinkPreview;

  /// Deserializes from JSON.
  factory LinkPreview.fromJson(Map<String, dynamic> json) =>
      _$LinkPreviewFromJson(json);
}

/// The decrypted payload of a message, matching the React client's
/// `DecryptedMessage` shape exactly.
///
/// This is what comes out of the Double Ratchet after decryption.
@freezed
class DecryptedMessage with _$DecryptedMessage {
  /// Creates a [DecryptedMessage] instance.
  const factory DecryptedMessage({
    required String text,
    String? replyTo,
    String? mediaUrl,

    /// `'message'` for text, `'media'` for media attachments.
    @Default('message') String type,
    String? aesKeyBase64,
    String? ivBase64,
    String? mimeType,
    String? inlineThumbnail,
    LinkPreview? linkPreview,
  }) = _DecryptedMessage;

  /// Deserializes from JSON.
  factory DecryptedMessage.fromJson(Map<String, dynamic> json) =>
      _$DecryptedMessageFromJson(json);
}
