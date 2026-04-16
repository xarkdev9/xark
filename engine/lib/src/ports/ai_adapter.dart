/// Pluggable AI adapter for streaming LLM responses.
///
/// Customers can implement this for OpenAI, Anthropic, Gemini, or custom LLMs.
/// The engine calls [streamResponse] -- it never imports a specific AI SDK
/// directly.
abstract class AIAdapter {
  /// Stream AI responses for a given prompt in a group context.
  ///
  /// Returns chunks of text as they arrive (SSE-style).
  Stream<AIResponseChunk> streamResponse({
    required String prompt,
    required String groupId,
    required String authToken,
    required Uri serverBaseUrl,
  });
}

/// A single chunk from an AI streaming response.
class AIResponseChunk {
  /// Creates an [AIResponseChunk].
  const AIResponseChunk({required this.text, this.done = false, this.error});

  /// The text content of this chunk.
  final String text;

  /// Whether this is the final chunk in the stream.
  final bool done;

  /// Error message, if the stream encountered an error.
  final String? error;
}
