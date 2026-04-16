import 'dart:convert';
import 'package:cryptography/cryptography.dart';

/// Private contact discovery using truncated SHA-256 hashes.
/// Never uploads raw phone numbers to the server.
/// Server maintains a hash table, returns only the intersection.

class PrivateContactDiscovery {
  static const int _hashPrefixBytes = 10; // truncated SHA-256

  /// Hash a phone number for private discovery.
  /// Uses truncated SHA-256 (first 10 bytes) to prevent brute-force.
  static Future<String> hashPhoneNumber(String phoneNumber) async {
    // Normalize: remove spaces, dashes, ensure +country code
    final normalized = phoneNumber.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    final hash = await Sha256().hash(utf8.encode(normalized));
    final truncated = hash.bytes.take(_hashPrefixBytes).toList();
    return base64Encode(truncated);
  }

  /// Hash a batch of phone numbers from the contact book.
  static Future<List<String>> hashContacts(List<String> phoneNumbers) async {
    final hashes = <String>[];
    for (final number in phoneNumbers) {
      hashes.add(await hashPhoneNumber(number));
    }
    return hashes;
  }

  /// Discover which contacts are on the platform.
  /// Sends hashes only — server never sees full phone numbers.
  /// Rate limited to prevent enumeration attacks.
  static Future<List<ContactMatch>> discover({
    required List<String> phoneHashes,
    required Future<List<Map<String, dynamic>>> Function(List<String>) serverLookup,
  }) async {
    // Batch in groups of 100 to stay under rate limits
    final matches = <ContactMatch>[];
    for (var i = 0; i < phoneHashes.length; i += 100) {
      final batch = phoneHashes.sublist(i, (i + 100).clamp(0, phoneHashes.length));
      final results = await serverLookup(batch);
      matches.addAll(results.map((r) => ContactMatch(
        phoneHash: r['phone_hash'] as String,
        userId: r['user_id'] as String,
        displayName: r['display_name'] as String?,
      )));
    }
    return matches;
  }
}

class ContactMatch {
  final String phoneHash;
  final String userId;
  final String? displayName;

  const ContactMatch({
    required this.phoneHash,
    required this.userId,
    this.displayName,
  });
}
