/// White-label brand configuration.
/// Customers provide their brand identity at initialization.
/// All UI-facing strings, endpoints, and identifiers are configurable.

class BrandConfig {
  /// Application display name (shown in notifications, app lock prompt).
  /// Example: 'hello', 'TeamChat', 'SecureMsg'
  final String appName;

  /// AI assistant display name (used for AI message type and @mention detection).
  /// Example: '@hello', '@buddy', '@ai'
  final String aiName;

  /// AI streaming endpoint path (relative to serverBaseUrl).
  /// Example: '/api/hello', '/api/ai', '/api/assistant'
  final String aiEndpoint;

  /// Push notification channel ID (Android) and category (iOS).
  /// Example: 'hello_messages', 'myapp_messages'
  final String pushChannelId;

  /// Push notification channel display name.
  /// Example: 'Messages', 'Chat Messages'
  final String pushChannelName;

  /// Default sender name for fallback push notifications.
  /// Shown when decryption fails: "You may have new messages"
  final String fallbackSenderName;

  const BrandConfig({
    this.appName = 'hello',
    this.aiName = '@hello',
    this.aiEndpoint = '/api/hello',
    this.pushChannelId = 'e2ee_chat_messages',
    this.pushChannelName = 'Messages',
    this.fallbackSenderName = 'Chat',
  });
}
