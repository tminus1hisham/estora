/// Typed failures.
///
/// Repositories return `Result<T>` rather than throwing, so callers cannot
/// forget to handle an error path. Section 65 requires consistent error
/// handling; this is the client half of that.
library;

sealed class Failure {
  const Failure(this.message, {this.code});

  /// Human-readable message, safe to show to a tenant.
  final String message;

  /// Machine-readable code from the API envelope, when there is one.
  final String? code;

  @override
  String toString() => '$runtimeType(${code ?? '-'}): $message';
}

/// No connectivity, DNS failure, timeout.
final class NetworkFailure extends Failure {
  const NetworkFailure([
    super.message = 'No internet connection. Check your network and try again.',
  ]) : super(code: 'network');
}

/// 401/403. The router listens for this and bounces to login.
final class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure([
    super.message = 'Your session has expired. Please sign in again.',
  ]) : super(code: 'unauthorized');
}

/// 403 specifically for cross-tenant access (section 74). A tenant must never
/// reach another tenant's records; if the server says no, we surface it as-is
/// rather than retrying.
final class ForbiddenFailure extends Failure {
  const ForbiddenFailure([
    super.message = 'You do not have access to this item.',
  ]) : super(code: 'forbidden');
}

final class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'We could not find that item.'])
    : super(code: 'not_found');
}

/// 422. [fieldErrors] maps a field name to its first error message so forms can
/// highlight the offending input.
final class ValidationFailure extends Failure {
  const ValidationFailure(
    super.message, {
    this.fieldErrors = const <String, String>{},
  }) : super(code: 'validation');

  final Map<String, String> fieldErrors;
}

/// 409. Raised when a unit was taken between browsing and booking
/// (section 48 forbids double-booking), or a state transition is no longer
/// legal for the entity's current status (section 81).
final class ConflictFailure extends Failure {
  const ConflictFailure(super.message) : super(code: 'conflict');
}

final class ServerFailure extends Failure {
  const ServerFailure([
    super.message = 'Something went wrong on our side. Please try again.',
  ]) : super(code: 'server');
}

final class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'Something went wrong.'])
    : super(code: 'unknown');
}

/// The current API does not provide this capability.
final class UnsupportedFeatureFailure extends Failure {
  const UnsupportedFeatureFailure([
    super.message = 'This feature is currently unavailable.',
  ]) : super(code: 'unsupported_feature');
}
