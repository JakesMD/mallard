import 'package:equatable/equatable.dart';

/// {@template mallard.result}
///
/// Represents a result that can either be successful or fail.
///
/// {@endtemplate}
abstract class Result<S, F> {
  /// {@macro mallard.result}
  const Result();

  /// {@template mallard.result.resolve}
  ///
  /// Resolves the result into a single type.
  ///
  /// {@endtemplate}
  T resolve<T>({
    required T Function(S success) onSuccess,
    required T Function(F failure) onFailure,
  }) => succeeded ? onSuccess(asSuccess) : onFailure(asFailure);

  /// {@template mallard.result.convert_both}
  ///
  /// Converts both the success and failure types of the result.
  ///
  /// {@endtemplate}
  Result<S2, F2> convertBoth<S2, F2>({
    required S2 Function(S success) onSuccess,
    required F2 Function(F failure) onFailure,
  }) => succeeded
      ? Success(onSuccess(asSuccess))
      : Failure(
          onFailure(asFailure),
          (this as Failure<S, F>).exception,
          (this as Failure<S, F>).stackTrace,
        );

  /// {@template mallard.result.convert}
  ///
  /// Converts the success type of the result.
  ///
  /// {@endtemplate}
  Result<S2, F> convert<S2>(S2 Function(S success) onSuccess) => succeeded
      ? Success(onSuccess(asSuccess))
      : Failure(
          asFailure,
          (this as Failure<S, F>).exception,
          (this as Failure<S, F>).stackTrace,
        );

  /// {@template mallard.result.convert_failure}
  ///
  /// Converts the failure type of the result.
  ///
  /// {@endtemplate}
  Result<S, F2> convertFailure<F2>(F2 Function(F failure) onFailure) =>
      succeeded
      ? Success(asSuccess)
      : Failure(
          onFailure(asFailure),
          (this as Failure<S, F>).exception,
          (this as Failure<S, F>).stackTrace,
        );

  /// {@template mallard.result.recover_when}
  ///
  /// Recovers from a failure when a specified condition is met.
  ///
  /// {@endtemplate}
  Result<S, F> recoverWhen({
    required bool Function(F failure) check,
    required S Function(F failure) then,
  }) => failed && check(asFailure) ? Success(then(asFailure)) : this;

  /// {@template mallard.result.ensure}
  ///
  /// Ensures that a success value satisfies a condition, otherwise converts it
  /// to a failure.
  ///
  /// {@endtemplate}
  Result<S, F> ensure({
    required bool Function(S success) check,
    required F Function(S success) otherwise,
  }) => succeeded && !check(asSuccess) ? Failure(otherwise(asSuccess)) : this;

  /// {@template mallard.result.succeeded}
  ///
  /// Returns 'true' if the type is a success, otherwise 'false'.
  ///
  /// {@endtemplate}
  bool get succeeded => this is Success<S, F>;

  /// {@template mallard.result.failed}
  ///
  /// Returns 'true' if the type is a failure, otherwise 'false'.
  ///
  /// {@endtemplate}
  bool get failed => this is Failure<S, F>;

  /// {@template mallard.result.as_success}
  ///
  /// Returns the success value of the result.
  ///
  /// {@endtemplate}
  S get asSuccess {
    assert(succeeded, 'Result is not a success.');
    return (this as Success<S, F>).value;
  }

  /// {@template mallard.result.as_failure}
  ///
  /// Returns the failure value of the result.
  ///
  /// {@endtemplate}
  F get asFailure {
    assert(failed, 'Result is not a failure.');
    return (this as Failure<S, F>).value;
  }
}

/// {@template mallard.success}
///
/// Represents a successful result.
///
/// {@endtemplate}
class Success<S, F> extends Result<S, F> with EquatableMixin {
  /// {@macro mallard.success}
  const Success(this.value);

  /// The success value.
  final S value;

  /// A short version of [value].
  S get val => value;

  @override
  List<Object?> get props => [value];
}

/// {@template mallard.failure}
///
/// Represents a failed result.
///
/// {@endtemplate}
class Failure<S, F> extends Result<S, F> with EquatableMixin {
  /// {@macro mallard.failure}
  const Failure(this.value, [this.exception, this.stackTrace]);

  /// The failure value.
  final F value;

  /// The exception that caused the failure, if available.
  final Object? exception;

  /// The stack trace of the failure, if available.
  final StackTrace? stackTrace;

  /// A short version of [value].
  F get val => value;

  @override
  List<Object?> get props => [value, exception, stackTrace];
}
