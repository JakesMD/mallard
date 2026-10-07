import 'dart:async';

import 'package:mallard/mallard.dart';
import 'package:mallard/src/result.dart' show RetypeFailure;
import 'package:mallard/src/run_reporting.dart';

/// {@template mallard.task}
///
/// A deferred operation that produces a [Result] each time it is run.
///
/// Nothing happens until [run], and every call runs the operation again.
///
/// {@endtemplate}
class Task<S, F> {
  /// {@macro mallard.task}
  ///
  /// The function returns the [Result] itself. Nothing is caught: a throw
  /// completes [run] with that error. Use [Task.attempt] to catch throws as
  /// failures.
  const Task(FutureOr<Result<S, F>> Function() run) : _run = run;

  /// {@template mallard.task.attempt}
  ///
  /// Runs a function that may throw, catching a throw as a [Failure].
  ///
  /// The failure holds `handle(e)`, the exception and the stack trace. If
  /// `handle` itself throws, the task completes with that error.
  ///
  /// {@endtemplate}
  factory Task.attempt({
    required FutureOr<S> Function() run,
    required F Function(Object e) handle,
  }) => Task(() async {
    // Every capturing operator on Task and ResultStream goes through here, so
    // this is the one place a throw becomes a failure.
    try {
      return Success(await run());
    } on Object catch (e, s) {
      return Failure(handle(e), e, s);
    }
  });

  /// {@template mallard.task.succeed}
  ///
  /// Creates a task that succeeds with the given value, for stubbing in tests:
  ///
  /// ```dart
  /// when(() => weatherApi.fetchForecast(any()))
  ///     .thenReturn(Task.succeed(Forecast(high: 21)));
  /// ```
  ///
  /// {@endtemplate}
  factory Task.succeed(S value) => Task(() async => Success<S, F>(value));

  /// {@template mallard.task.fail}
  ///
  /// Creates a task that fails with the given value and an optional exception
  /// and stack trace, for stubbing in tests:
  ///
  /// ```dart
  /// when(() => weatherApi.fetchForecast(any()))
  ///     .thenReturn(Task.fail(WeatherError.offline));
  /// ```
  ///
  /// {@endtemplate}
  factory Task.fail(F value, [Object? exception, StackTrace? stackTrace]) =>
      Task(() async => Failure(value, exception, stackTrace));

  final FutureOr<Result<S, F>> Function() _run;

  /// {@template mallard.task.run}
  ///
  /// Runs the task and returns its [Result].
  ///
  /// Reports the result to [Mallard.onTaskSuccess] or [Mallard.onTaskFailure],
  /// unless this is an inner run (see [Mallard]).
  ///
  /// {@endtemplate}
  FutureOr<Result<S, F>> run() => runTask(_run);

  /// {@template mallard.task.apply}
  ///
  /// Maps the whole [Result].
  ///
  /// {@endtemplate}
  Task<S2, F2> apply<S2, F2>(
    Result<S2, F2> Function(Result<S, F> result) onRun,
  ) => Task(() async => onRun(await run()));

  /// {@template mallard.task.then}
  ///
  /// Runs a function that returns a [Result] with the success value. A failure
  /// skips it.
  ///
  /// {@endtemplate}
  Task<S2, F> then<S2>(FutureOr<Result<S2, F>> Function(S success) run) => Task(
    () async => switch (await this.run()) {
      Success(:final value) => await run(value),
      final Failure<S, F> f => f.retype(),
    },
  );

  /// {@template mallard.task.then_attempt}
  ///
  /// Runs a function that may throw with the success value, catching a throw
  /// as [Task.attempt] does. A failure skips it.
  ///
  /// {@endtemplate}
  Task<S2, F> thenAttempt<S2>({
    required FutureOr<S2> Function(S success) run,
    required F Function(Object e) handle,
  }) =>
      chain((success) => Task.attempt(run: () => run(success), handle: handle));

  /// {@template mallard.task.chain}
  ///
  /// Runs the task built from the success value. A failure skips it.
  ///
  /// {@endtemplate}
  Task<S2, F> chain<S2>(Task<S2, F> Function(S success) task) => Task(
    () async => switch (await run()) {
      Success(:final value) => await task(value).run(),
      final Failure<S, F> f => f.retype(),
    },
  );

  /// {@template mallard.task.chain_stream}
  ///
  /// Starts the result stream built from the success value.
  ///
  /// If the task fails, the stream emits its failure and closes. Each run of
  /// the stream runs the task again. The task and the inner stream are inner
  /// runs (see [Mallard]), so only the stream callbacks report, including the
  /// task's failure.
  ///
  /// {@endtemplate}
  ResultStream<S2, F> chainStream<S2>(
    ResultStream<S2, F> Function(S success) stream,
  ) => ResultStream.fromTask(this).chainStream(stream);

  /// {@template mallard.task.then_attempt_stream}
  ///
  /// Starts the plain stream built from the success value, catching its errors
  /// as [ResultStream.attempt] does. Otherwise it behaves like [chainStream].
  ///
  /// {@endtemplate}
  ResultStream<S2, F> thenAttemptStream<S2>({
    required Stream<S2> Function(S success) run,
    required F Function(Object e) handle,
  }) => ResultStream.fromTask(this).thenAttemptStream(run: run, handle: handle);

  /// {@macro mallard.result.convert_both}
  Task<S2, F2> convertBoth<S2, F2>({
    required S2 Function(S success) onSuccess,
    required F2 Function(F failure) onFailure,
  }) => apply((r) => r.convertBoth(onSuccess: onSuccess, onFailure: onFailure));

  /// {@macro mallard.result.convert}
  Task<S2, F> convert<S2>(S2 Function(S success) onSuccess) =>
      apply((r) => r.convert(onSuccess));

  /// {@macro mallard.result.convert_failure}
  Task<S, F2> convertFailure<F2>(F2 Function(F failure) onFailure) =>
      apply((r) => r.convertFailure(onFailure));

  /// {@macro mallard.result.recover_when}
  Task<S, F> recoverWhen({
    required bool Function(F failure) check,
    required S Function(F failure) then,
  }) => apply((r) => r.recoverWhen(check: check, then: then));

  /// {@macro mallard.result.ensure}
  Task<S, F> ensure({
    required bool Function(S success) check,
    required F Function(S success) otherwise,
  }) => apply((r) => r.ensure(check: check, otherwise: otherwise));
}
