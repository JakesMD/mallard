import 'package:equatable/equatable.dart';

/// {@template mallard.result}
///
/// The outcome of an operation that can fail: a [Success] or a [Failure].
///
/// {@endtemplate}
sealed class Result<S, F> {
  /// {@macro mallard.result}
  const Result();

  /// {@template mallard.result.resolve}
  ///
  /// Folds both tracks into one value, mapping a success value or a failure
  /// value.
  ///
  /// {@endtemplate}
  T resolve<T>({
    required T Function(S success) onSuccess,
    required T Function(F failure) onFailure,
  }) => switch (this) {
    Success(:final value) => onSuccess(value),
    Failure(:final value) => onFailure(value),
  };

  /// {@template mallard.result.convert_both}
  ///
  /// Maps the success value and the failure value.
  ///
  /// {@endtemplate}
  Result<S2, F2> convertBoth<S2, F2>({
    required S2 Function(S success) onSuccess,
    required F2 Function(F failure) onFailure,
  }) => switch (this) {
    Success(:final value) => Success(onSuccess(value)),
    final Failure<S, F> f => f._withValue(onFailure(f.value)),
  };

  /// {@template mallard.result.convert}
  ///
  /// Maps the success value. A failure passes through.
  ///
  /// {@endtemplate}
  Result<S2, F> convert<S2>(S2 Function(S success) onSuccess) => switch (this) {
    Success(:final value) => Success(onSuccess(value)),
    final Failure<S, F> f => f._withValue(f.value),
  };

  /// {@template mallard.result.convert_failure}
  ///
  /// Maps the failure value. A success passes through.
  ///
  /// {@endtemplate}
  Result<S, F2> convertFailure<F2>(F2 Function(F failure) onFailure) =>
      switch (this) {
        Success(:final value) => Success(value),
        final Failure<S, F> f => f._withValue(onFailure(f.value)),
      };

  /// {@template mallard.result.recover_when}
  ///
  /// Turns a failure that passes `check` into a success of `then(failure)`.
  ///
  /// {@endtemplate}
  Result<S, F> recoverWhen({
    required bool Function(F failure) check,
    required S Function(F failure) then,
  }) => switch (this) {
    Failure(:final value) when check(value) => Success(then(value)),
    _ => this,
  };

  /// {@template mallard.result.ensure}
  ///
  /// Turns a success that fails `check` into a failure of
  /// `otherwise(success)`.
  ///
  /// {@endtemplate}
  Result<S, F> ensure({
    required bool Function(S success) check,
    required F Function(S success) otherwise,
  }) => switch (this) {
    Success(:final value) when !check(value) => Failure(otherwise(value)),
    _ => this,
  };

  /// {@template mallard.result.succeeded}
  ///
  /// Whether this is a [Success].
  ///
  /// {@endtemplate}
  bool get succeeded => this is Success<S, F>;

  /// {@template mallard.result.failed}
  ///
  /// Whether this is a [Failure].
  ///
  /// {@endtemplate}
  bool get failed => this is Failure<S, F>;

  /// {@template mallard.result.as_success}
  ///
  /// The success value. Throws if this is a [Failure].
  ///
  /// {@endtemplate}
  S get asSuccess {
    assert(succeeded, 'Result is not a success.');
    return (this as Success<S, F>).value;
  }

  /// {@template mallard.result.as_failure}
  ///
  /// The failure value. Throws if this is a [Success].
  ///
  /// {@endtemplate}
  F get asFailure {
    assert(failed, 'Result is not a failure.');
    return (this as Failure<S, F>).value;
  }
}

/// {@template mallard.success}
///
/// A [Result] holding the value an operation produced.
///
/// {@endtemplate}
final class Success<S, F> extends Result<S, F> with Equatable {
  /// {@macro mallard.success}
  const Success(this.value);

  /// The success value.
  final S value;

  /// Shorthand for [value].
  S get val => value;

  @override
  List<Object?> get props => [value];
}

/// {@template mallard.failure}
///
/// A [Result] holding the reason an operation failed.
///
/// A failure made from a caught throw also holds its exception and stack
/// trace. Every operator that passes a failure along keeps them.
///
/// {@endtemplate}
final class Failure<S, F> extends Result<S, F> with Equatable {
  /// {@macro mallard.failure}
  const Failure(this.value, [this.exception, this.stackTrace]);

  /// The failure value.
  final F value;

  /// The exception that caused the failure, if one was caught.
  final Object? exception;

  /// The stack trace of [exception], if one was caught.
  final StackTrace? stackTrace;

  /// Shorthand for [value].
  F get val => value;

  // The one place a failure's exception and stack trace carry over to a new
  // failure.
  Failure<S2, F2> _withValue<S2, F2>(F2 value) =>
      Failure(value, exception, stackTrace);

  @override
  List<Object?> get props => [value, exception, stackTrace];
}

/// Lets operators pass a [Failure] through under another success type.
///
/// Hidden from the public export.
extension RetypeFailure<S, F> on Failure<S, F> {
  /// Returns this failure under the success type [S2].
  Failure<S2, F> retype<S2>() => _withValue(value);
}
