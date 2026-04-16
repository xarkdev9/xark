import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:e2ee_chat_sdk/src/config/brand_config.dart';
import 'package:e2ee_chat_sdk/src/ports/ai_adapter.dart';

/// Server-Sent Events AI adapter.
///
/// Connects to any SSE endpoint that streams JSON chunks.
/// Default implementation for the hello/e2ee_chat backend.
///
/// The endpoint path is taken from [BrandConfig.aiEndpoint], making it
/// configurable per white-label deployment.
class SSEAIAdapter implements AIAdapter {
  /// Creates an [SSEAIAdapter].
  SSEAIAdapter({required this.brand});

  /// Brand configuration for endpoint resolution.
  final BrandConfig brand;

  @override
  Stream<AIResponseChunk> streamResponse({
    required String prompt,
    required String groupId,
    required String authToken,
    required Uri serverBaseUrl,
  }) async* {
    try {
      final uri = serverBaseUrl.resolve(brand.aiEndpoint);
      final request = http.Request('POST', uri);
      request.headers['Content-Type'] = 'application/json';
      request.headers['Authorization'] = 'Bearer $authToken';
      request.body = jsonEncode(<String, dynamic>{
        'prompt': prompt,
        'groupId': groupId,
      });

      final response = await http.Client().send(request);

      await for (final chunk in response.stream.transform(utf8.decoder)) {
        for (final line in chunk.split('\n')) {
          if (line.startsWith('data: ')) {
            try {
              final json =
                  jsonDecode(line.substring(6)) as Map<String, dynamic>;
              if (json['done'] == true) {
                yield const AIResponseChunk(text: '', done: true);
                return;
              }
              if (json['error'] != null) {
                yield AIResponseChunk(
                  text: '',
                  error: json['error'] as String,
                );
                return;
              }
              yield AIResponseChunk(text: json['text'] as String? ?? '');
            } catch (_) {
              // Skip malformed SSE lines.
            }
          }
        }
      }
    } catch (e) {
      yield AIResponseChunk(text: '', error: e.toString());
    }
  }
}

/// No-op AI adapter for apps without AI features.
class NoopAIAdapter implements AIAdapter {
  @override
  Stream<AIResponseChunk> streamResponse({
    required String prompt,
    required String groupId,
    required String authToken,
    required Uri serverBaseUrl,
  }) async* {
    yield const AIResponseChunk(text: 'AI not configured', done: true);
  }
}
