import 'failure.dart';

/// The return type of every repository method.
///
/// Exceptions never cross a layer boundary: the data layer catches whatever the
/// transport throws and converts it to a [Failure]. Controllers pattern-match.
sealed class Result<T> {
  const Result();

  const factory Result.ok(T value) = Ok<T>;
  const factory Result.err(Failure failure) = Err<T>;

  bool get isOk => this is Ok<T>;
  bool get isErr => this is Err<T>;

  T? get valueOrNull => switch (this) {
    Ok<T>(:final value) => value,
    Err<T>() => null,
  };

  Failure? get failureOrNull => switch (this) {
    Ok<T>() => null,
    Err<T>(:final failure) => failure,
  };

  /// Unwraps, or throws. Only for tests and for call sites that have already
  /// checked [isOk].
  T get value => switch (this) {
    Ok<T>(:final value) => value,
    Err<T>(:final failure) => throw StateError('Unwrapped an Err: $failure'),
  };

  Result<R> map<R>(R Function(T value) transform) => switch (this) {
    Ok<T>(:final value) => Ok<R>(transform(value)),
    Err<T>(:final failure) => Err<R>(failure),
  };

  Future<Result<R>> mapAsync<R>(Future<R> Function(T value) transform) async =>
      switch (this) {
        Ok<T>(:final value) => Ok<R>(await transform(value)),
        Err<T>(:final failure) => Err<R>(failure),
      };

  R fold<R>(R Function(T value) onOk, R Function(Failure failure) onErr) =>
      switch (this) {
        Ok<T>(:final value) => onOk(value),
        Err<T>(:final failure) => onErr(failure),
      };
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);

  @override
  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.failure);

  final Failure failure;
}
