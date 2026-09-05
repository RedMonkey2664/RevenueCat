import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meta/meta.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/progress_service.dart' show sharedPreferencesProvider;

/// What a Kotak Neo connection needs.
///
/// Two halves, from two different places:
///   • [consumerKey] / [consumerSecret] identify the *app*. Somi obtains one
///     pair from Kotak and they are the same for every user.
///   • [mobileNumber] / [password] / the OTP identify the *user*, and are
///     entered per person on the connect screen.
///
/// ⚠ STORAGE — this is written to `shared_preferences`, which is NOT secure
/// storage. On Android it is a world-readable-by-root XML file; on iOS it is
/// an unencrypted plist in the app container. Acceptable for the app-level
/// consumer key, NOT acceptable for a user's broker password.
///
/// So: the password is deliberately never persisted — only the short-lived
/// session token is, and only until it expires. If Kotak's flow later needs
/// the password kept, add `flutter_secure_storage` first. This is the one
/// decision in the broker path worth not getting wrong.
@immutable
class BrokerCredentials {
  const BrokerCredentials({
    required this.consumerKey,
    required this.consumerSecret,
    this.mobileNumber,
  });

  final String consumerKey;
  final String consumerSecret;

  /// Remembered for convenience so the user does not retype it. Not a secret.
  final String? mobileNumber;

  bool get isComplete =>
      consumerKey.trim().isNotEmpty && consumerSecret.trim().isNotEmpty;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'consumer_key': consumerKey,
        'consumer_secret': consumerSecret,
        if (mobileNumber != null) 'mobile': mobileNumber,
      };

  factory BrokerCredentials.fromJson(Map<String, dynamic> json) {
    return BrokerCredentials(
      consumerKey: json['consumer_key'] as String? ?? '',
      consumerSecret: json['consumer_secret'] as String? ?? '',
      mobileNumber: json['mobile'] as String?,
    );
  }
}

/// A live broker session.
@immutable
class BrokerSession {
  const BrokerSession({
    required this.accessToken,
    required this.sessionId,
    required this.expiresAt,
    this.userId,
  });

  final String accessToken;
  final String sessionId;
  final DateTime expiresAt;
  final String? userId;

  bool get isValid => DateTime.now().toUtc().isBefore(expiresAt);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'access_token': accessToken,
        'session_id': sessionId,
        'expires_at': expiresAt.toIso8601String(),
        if (userId != null) 'user_id': userId,
      };

  factory BrokerSession.fromJson(Map<String, dynamic> json) {
    return BrokerSession(
      accessToken: json['access_token'] as String,
      sessionId: json['session_id'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      userId: json['user_id'] as String?,
    );
  }
}

/// Reads and writes the broker connection state.
class BrokerCredentialStore {
  const BrokerCredentialStore(this._prefs);

  static const String _credentialsKey = 'broker_credentials_v1';
  static const String _sessionKey = 'broker_session_v1';

  final SharedPreferences _prefs;

  BrokerCredentials? readCredentials() {
    final String? raw = _prefs.getString(_credentialsKey);
    if (raw == null) return null;
    try {
      return BrokerCredentials.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } on Object catch (_) {
      return null;
    }
  }

  Future<void> writeCredentials(BrokerCredentials c) =>
      _prefs.setString(_credentialsKey, jsonEncode(c.toJson()));

  BrokerSession? readSession() {
    final String? raw = _prefs.getString(_sessionKey);
    if (raw == null) return null;
    try {
      final BrokerSession s = BrokerSession.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      // An expired token is worse than none: it produces confusing 401s
      // instead of an honest "not connected" state.
      return s.isValid ? s : null;
    } on Object catch (_) {
      return null;
    }
  }

  Future<void> writeSession(BrokerSession s) =>
      _prefs.setString(_sessionKey, jsonEncode(s.toJson()));

  Future<void> clearSession() => _prefs.remove(_sessionKey);

  Future<void> clearAll() async {
    await _prefs.remove(_sessionKey);
    await _prefs.remove(_credentialsKey);
  }
}

final Provider<BrokerCredentialStore> brokerCredentialStoreProvider =
    Provider<BrokerCredentialStore>(
  (Ref ref) => BrokerCredentialStore(ref.watch(sharedPreferencesProvider)),
);
