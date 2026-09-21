/// Persistence for the auth session.
///
/// Section 72 requires refresh tokens to be stored securely on the device, and
/// section 74 requires refresh token rotation. The rotation itself is a
/// transport concern (see the Dio interceptor); this interface is only about
/// where the tokens live.
library;

import 'dart:convert';

class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;

  /// How long a token is assumed good for when nothing says otherwise.
  ///
  /// The contract returns a token and a refresh token but no expiry. Rather
  /// than treat the session as eternal, it is treated as short: the client
  /// renews on the hour, and a 401 renews immediately regardless. An
  /// assumption that expires too early costs one extra round trip; one that
  /// expires too late costs a failed request in front of the tenant.
  static const Duration assumedLife = Duration(hours: 1);

  /// When [accessToken] stops being accepted, from the best source to hand.
  ///
  /// An `expiresAt` the response [stated] wins. Failing that, the token's own
  /// `exp` claim — the API issues JWTs, and the claim is the server's word on
  /// the matter, which is what a renewal has to beat: the refresh route is
  /// behind the same bearer gate as everything else, so a token must be
  /// renewed *before* it dies, not after. Failing both, [assumedLife] from now.
  static DateTime expiryOf(String accessToken, {String? stated}) =>
      DateTime.tryParse(stated ?? '') ??
      jwtExpiry(accessToken) ??
      DateTime.now().add(assumedLife);

  /// The `exp` claim of a JWT, or null when [token] is not one.
  ///
  /// Reads the claim without verifying the signature: the client is not the
  /// party the signature is for, and a forged expiry only ever costs the
  /// forger a rejected request.
  static DateTime? jwtExpiry(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      final payload = json.decode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      final exp = payload is Map ? payload['exp'] : null;
      final seconds = switch (exp) {
        num value => value.toInt(),
        String value => int.tryParse(value),
        _ => null,
      };
      if (seconds == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
    } on FormatException {
      return null;
    }
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Treat a token that expires within the next minute as already expired, so
  /// a request does not go out with a token that dies mid-flight.
  bool get isNearlyExpired =>
      DateTime.now().add(const Duration(minutes: 1)).isAfter(expiresAt);

  AuthTokens copyWith({
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
  }) {
    return AuthTokens(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}

abstract interface class TokenStore {
  Future<AuthTokens?> read();
  Future<void> write(AuthTokens tokens);
  Future<void> clear();

  /// Whether the tenant has opted into biometric unlock (section 72). Stored
  /// alongside the tokens because clearing the session must clear this too.
  Future<bool> isBiometricEnabled();
  Future<void> setBiometricEnabled(bool enabled);
}
