/// E2EE-safe link unfurling for Flutter.
/// Detects URLs, fetches OG metadata via blind proxy, includes in
/// encrypted message payload.

class LinkPreview {
  final String url;
  final String? title;
  final String? description;
  final String? imageBase64;
  final String? siteName;
  final String domain;

  const LinkPreview({
    required this.url,
    this.title,
    this.description,
    this.imageBase64,
    this.siteName,
    required this.domain,
  });

  Map<String, dynamic> toJson() => {
        'type': 'link_preview',
        'url': url,
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (imageBase64 != null) 'imageBase64': imageBase64,
        if (siteName != null) 'siteName': siteName,
        'domain': domain,
      };

  factory LinkPreview.fromJson(Map<String, dynamic> json) => LinkPreview(
        url: json['url'] as String,
        title: json['title'] as String?,
        description: json['description'] as String?,
        imageBase64: json['imageBase64'] as String?,
        siteName: json['siteName'] as String?,
        domain: json['domain'] as String? ?? '',
      );
}

/// Detect the first URL in a text string.
String? detectUrl(String text) {
  final regex = RegExp(r'https?://[^\s<>"]+', caseSensitive: false);
  final match = regex.firstMatch(text);
  return match?.group(0);
}
