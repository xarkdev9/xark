import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

part 'media_payload.freezed.dart';

/// Raw media bytes payload passed from the UI layer to the engine.
///
/// This model is used in-memory only and does not need JSON serialization.
/// `Uint8List` cannot be round-tripped through JSON without a custom converter,
/// so `fromJson`/`toJson` are intentionally omitted.
@Freezed(toJson: false, fromJson: false)
class MediaPayload with _$MediaPayload {
  /// Creates a [MediaPayload] instance.
  const factory MediaPayload({
    required Uint8List bytes,
    required String mimeType,
    required String fileName,
    Uint8List? thumbnailBytes,
    int? durationMs,
    int? width,
    int? height,
  }) = _MediaPayload;
}
