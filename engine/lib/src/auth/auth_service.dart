import 'dart:convert';
import 'package:http/http.dart' as http;

/// Handles authentication flows for the hello engine.
/// Called by the UI BEFORE engine.initialize() to obtain the JWT
/// needed for ChatEngineConfig.authToken.
///
/// The UI provides the Firebase ID token (from phone OTP verification).
/// This service exchanges it for a Supabase-compatible JWT via /api/phone-auth.

class AuthService {
  final Uri _serverBaseUrl;

  AuthService(this._serverBaseUrl);

  /// Exchange a Firebase ID token for a Supabase-compatible JWT.
  /// Called after the user completes phone OTP verification via Firebase Auth.
  ///
  /// Returns [AuthResult] with the access token, user ID, and new user flag.
  /// Throws [AuthException] on failure.
  Future<AuthResult> authenticateWithFirebase({
    required String firebaseIdToken,
    String? displayName,
  }) async {
    final response = await http.post(
      _serverBaseUrl.resolve('/api/phone-auth'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'idToken': firebaseIdToken,
        if (displayName != null) 'displayName': displayName,
      }),
    );

    if (response.statusCode != 200) {
      final error = _parseError(response.body);
      throw AuthException(error, statusCode: response.statusCode);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return AuthResult(
      accessToken: data['accessToken'] as String,
      userId: data['userId'] as String,
      isNewUser: data['isNewUser'] as bool? ?? false,
    );
  }

  /// Dev-only: authenticate with username + password.
  /// Returns 404 in production (server rejects).
  Future<AuthResult> authenticateWithPassword({
    required String username,
    required String password,
  }) async {
    final response = await http.post(
      _serverBaseUrl.resolve('/api/dev-auto-login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );

    if (response.statusCode != 200) {
      final error = _parseError(response.body);
      throw AuthException(error, statusCode: response.statusCode);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return AuthResult(
      accessToken: data['accessToken'] as String? ?? data['token'] as String,
      userId: data['userId'] as String? ?? data['user_id'] as String,
      isNewUser: false,
    );
  }

  /// Join via invite link (name-only, no phone verification).
  Future<AuthResult> joinWithInvite({
    required String inviteCode,
    required String displayName,
  }) async {
    final response = await http.post(
      _serverBaseUrl.resolve('/api/join'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'token': inviteCode,
        'displayName': displayName,
      }),
    );

    if (response.statusCode != 200) {
      final error = _parseError(response.body);
      throw AuthException(error, statusCode: response.statusCode);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return AuthResult(
      accessToken: data['accessToken'] as String? ?? data['token'] as String,
      userId: data['userId'] as String? ?? data['user_id'] as String,
      isNewUser: true,
      groupId: data['groupId'] as String? ?? data['space_id'] as String?,
    );
  }

  String _parseError(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      return json['error'] as String? ?? 'Unknown error';
    } catch (_) {
      return body;
    }
  }
}

class AuthResult {
  final String accessToken;
  final String userId;
  final bool isNewUser;
  final String? groupId; // Only for invite joins

  const AuthResult({
    required this.accessToken,
    required this.userId,
    this.isNewUser = false,
    this.groupId,
  });
}

class AuthException implements Exception {
  final String message;
  final int statusCode;

  const AuthException(this.message, {this.statusCode = 0});

  @override
  String toString() => 'AuthException($statusCode): $message';
}
