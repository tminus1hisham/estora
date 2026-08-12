/// Persistence for the auth session.
///
/// Section 72 requires refresh tokens to be stored securely on the device, and
/// section 74 requires refresh token rotation. The rotation itself is a
/// transport concern (see the Dio interceptor); this interface is only about
/// where the tokens live.
library;

class AuthTokens {
  const AuthTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;

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
