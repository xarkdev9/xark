/// A single chunk from a streaming @hello AI response.
class HelloResponseChunk {
  /// Creates a [HelloResponseChunk].
  const HelloResponseChunk({
    required this.text,
    this.done = false,
    this.error,
  });

  /// The text content of this chunk.
  final String text;

  /// Whether this is the final chunk in the stream.
  final bool done;

  /// An error message, if the stream encountered an error.
  final String? error;
}
