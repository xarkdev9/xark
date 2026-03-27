/// On-device Small Language Model for local constraint detection.
/// Runs quantized models via CoreML (iOS) / NNAPI (Android) for
/// instant, private detection of dietary restrictions, budget limits, etc.
/// Saves massive server-side LLM API costs.

abstract class OnDeviceSLM {
  /// Check if on-device inference is available on this device.
  Future<bool> isAvailable();

  /// Detect constraints from user text (diet, budget, allergies, etc.)
  /// Returns structured constraint data without hitting the cloud.
  Future<List<DetectedConstraint>> detectConstraints(String text);

  /// Classify intent locally (question, command, preference, complaint)
  Future<String> classifyIntent(String text);
}

class DetectedConstraint {
  final String type;     // 'dietary', 'budget', 'allergy', 'schedule'
  final String value;    // 'vegetarian', '$50', 'peanuts', 'after 6pm'
  final double confidence;

  const DetectedConstraint({
    required this.type,
    required this.value,
    required this.confidence,
  });

  Map<String, dynamic> toJson() => {
    'type': type,
    'value': value,
    'confidence': confidence,
  };
}

/// Stub implementation for devices without ML capabilities.
/// Falls back to regex-based constraint detection.
class FallbackSLM implements OnDeviceSLM {
  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<List<DetectedConstraint>> detectConstraints(String text) async {
    final constraints = <DetectedConstraint>[];
    final lower = text.toLowerCase();

    // Simple regex patterns as fallback
    if (lower.contains('vegetarian') || lower.contains('vegan')) {
      constraints.add(const DetectedConstraint(type: 'dietary', value: 'vegetarian', confidence: 0.9));
    }
    if (lower.contains('halal') || lower.contains('kosher')) {
      constraints.add(DetectedConstraint(type: 'dietary', value: lower.contains('halal') ? 'halal' : 'kosher', confidence: 0.9));
    }
    if (RegExp(r'\$\d+').hasMatch(text)) {
      final match = RegExp(r'\$(\d+)').firstMatch(text);
      if (match != null) {
        constraints.add(DetectedConstraint(type: 'budget', value: '\$${match.group(1)}', confidence: 0.8));
      }
    }

    return constraints;
  }

  @override
  Future<String> classifyIntent(String text) async => 'unknown';
}
