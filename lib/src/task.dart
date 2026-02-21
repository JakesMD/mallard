// Required for the `Task.attempt` factory constructor, which catches exceptions
// and converts them to failures.
// ignore_for_file: avoid_catches_without_on_clauses

import 'package:mallard/mallard.dart';

/// {@template mallard.task}
///
/// Represents asynchronous tasks that can succeed or fail.
///
/// {@endtemplate}
class Task<S, F> {
  /// {@macro mallard.task}
  const Task(Future<Result<S, F>> Function() run) : _run = run;

  /// {@template mallard.task.attempt}
  ///
  /// Attempts to execute an asynchronous function and captures any exceptions
  /// as failures.
  ///
  /// {@endtemplate}
  factory Task.attempt({
    required Future<S> Function() run,
    required F Function(Object e) handle,
  }) => Task(() async {
    try {
      return Success(await run());
    } catch (e, s) {
      return Failure(handle(e), e, s);
    }
  });

  /// {@template mallard.task.succeed}
  ///
  /// Creates a task that immediately succeeds with the given value.
  ///
  /// This is used for testing.
  ///
  /// ``` dart
  /// test('Example', () {
  ///   when(() => temperatureClient.fetch(any())).thenReturn(Task.succeed(50));
  ///
  ///   final result = await weatherRepository.fetch('London').run();
  ///
  ///   expect(result.asSuccess.temperature, 50);
  /// });
  /// ```
  ///
  /// {@endtemplate}
  factory Task.succeed(S value) => Task(() async => Success<S, F>(value));

  /// {@template mallard.task.fail}
  ///
  /// Creates a task that immediately fails with the given value, exception, and
  /// stack trace.
  ///
  /// This is used for testing.
  ///
  /// ``` dart
  /// test('Example', () {
  ///   when(() => temperatureClient.fetch(any()))
  ///     .thenReturn(Task.fail('Network error'));
  ///
  ///   final result = await weatherRepository.fetch('London').run();
  ///
  ///   expect(result.asFailure, 'Network error');
  /// });
  /// ```
  ///
  /// {@endtemplate}
  factory Task.fail(F value, [Object? exception, StackTrace? stackTrace]) =>
      Task(() async => Failure(value, exception, stackTrace));

  final Future<Result<S, F>> Function() _run;

  /// {@template mallard.task.run}
  ///
  /// Executes the task and returns a [Future] that completes with a [Result]
  /// containing either a success value of type [S] or a failure value of type
  /// [F].
  ///
  /// This method also triggers the [Mallard.onTaskSuccess] and
  /// [Mallard.onTaskFailure] callbacks based on the outcome of the task.
  ///
  /// {@endtemplate}
  Future<Result<S, F>> run() async {
    final r = await _run();

    if (r.succeeded) {
      Mallard.onTaskSuccess(r.asSuccess);
    } else {
      Mallard.onTaskFailure(
        r.asFailure,
        (r as Failure<S, F>).exception,
        r.stackTrace,
      );
    }

    return r;
  }

  /// {@template mallard.task.apply}
  ///
  /// Applies a function to the result of the task, allowing for transformations
  /// of both success and failure values.
  ///
  /// {@endtemplate}
  Task<S2, F2> apply<S2, F2>(
    Result<S2, F2> Function(Result<S, F> result) onRun,
  ) => Task(() async => onRun(await _run()));

  /// {@template mallard.task.then}
  ///
  /// Chains another asynchronous function to be executed if the current task
  /// succeeds.
  ///
  /// {@endtemplate}
  Task<S2, F> then<S2>(Future<Result<S2, F>> Function(S success) run) => Task(
    () async {
      final r = await _run();
      return r.resolve(
        onSuccess: (s) => run(s),
        onFailure: (f) => Failure<S2, F>(
          f,
          (r as Failure<S, F>).exception,
          r.stackTrace,
        ),
      );
    },
  );

  /// {@template mallard.task.then_attempt}
  ///
  /// Chains another asynchronous function to be executed if the current task
  /// succeeds, while also catching any exceptions that may occur and converting
  /// them to failures.
  ///
  /// {@endtemplate}
  Task<S2, F> thenAttempt<S2>({
    required Future<S2> Function(S success) run,
    required F Function(Object e) handle,
  }) => Task(() async {
    final r = await _run();
    return r.resolve(
      onSuccess: (s) async {
        try {
          return Success(await run(s));
        } catch (e, s) {
          return Failure(handle(e), e, s);
        }
      },
      onFailure: (f) => Failure<S2, F>(
        f,
        (r as Failure<S, F>).exception,
        r.stackTrace,
      ),
    );
  });

  /// {@template mallard.task.chain}
  ///
  /// Chains another task to be executed if the current task succeeds.
  ///
  /// {@endtemplate}
  Task<S2, F> chain<S2>(Task<S2, F> Function(S success) task) => Task(() async {
    final r = await _run();
    return r.resolve(
      onSuccess: (success) => task(success)._run(),
      onFailure: (f) => Failure<S2, F>(
        f,
        (r as Failure<S, F>).exception,
        r.stackTrace,
      ),
    );
  });

  /// {@template mallard.task.convert_both}
  ///
  /// Converts both the success and failure types of the task's result.
  ///
  /// {@endtemplate}
  Task<S2, F2> convertBoth<S2, F2>({
    required S2 Function(S success) onSuccess,
    required F2 Function(F failure) onFailure,
  }) => apply((r) => r.convertBoth(onSuccess: onSuccess, onFailure: onFailure));

  /// {@template mallard.task.convert}
  ///
  /// Converts the success type of the task's result.
  ///
  /// {@endtemplate}
  Task<S2, F> convert<S2>(S2 Function(S success) onSuccess) =>
      apply((r) => r.convert(onSuccess));

  /// {@template mallard.task.convert_failure}
  ///
  /// Converts the failure type of the task's result.
  ///
  /// {@endtemplate}
  Task<S, F2> convertFailure<F2>(F2 Function(F failure) onFailure) =>
      apply((r) => r.convertFailure(onFailure));

  /// {@template mallard.task.recover_when}
  ///
  /// Recovers from a failure when a specified condition is met.
  ///
  /// {@endtemplate}
  Task<S, F> recoverWhen({
    required bool Function(F failure) check,
    required S Function(F failure) then,
  }) => apply((r) => r.recoverWhen(check: check, then: then));

  /// {@template mallard.task.ensure}
  ///
  /// Ensures that a success value satisfies a condition, otherwise converts it
  /// to a failure.
  ///
  /// {@endtemplate}
  Task<S, F> ensure({
    required bool Function(S success) check,
    required F Function(S success) otherwise,
  }) => apply((r) => r.ensure(check: check, otherwise: otherwise));
}
