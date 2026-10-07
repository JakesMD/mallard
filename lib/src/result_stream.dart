import 'dart:async';

import 'package:mallard/mallard.dart';
import 'package:mallard/src/relay.dart';
import 'package:mallard/src/result.dart' show RetypeFailure;
import 'package:mallard/src/run_reporting.dart';

/// {@template mallard.result_stream}
///
/// A deferred source that emits a sequence of [Result]s each time it is run.
///
/// Failures are data: a [Failure] never ends the stream. Operators apply to
/// each result as it arrives. An operator callback that throws turns that
/// event into an untyped stream error, and later events keep flowing. Untyped
/// stream errors pass through every operator.
///
/// {@endtemplate}
class ResultStream<S, F> {
  /// {@macro mallard.result_stream}
  ///
  /// The factory's stream emits [Result]s itself. Nothing is caught: a raw
  /// error event passes through as an untyped stream error. Use
  /// [ResultStream.attempt] to catch errors as failures.
  ///
  /// The factory is called on every run, so it must return a fresh or
  /// broadcast stream. Keep eager setup in the stream's `onListen` or in an
  /// `async*` body. In an `async*` body, `yield Failure(...)` reports a
  /// failure, while `throw` ends the stream with an untyped error.
  const ResultStream(Stream<Result<S, F>> Function() stream) : _stream = stream;

  /// {@template mallard.result_stream.attempt}
  ///
  /// Wraps a stream of plain values, catching its errors as failures.
  ///
  /// Each data event becomes a [Success], and each error event a [Failure]
  /// holding `handle(e)`, the exception and the stack trace. The stream
  /// carries on after an error, so sources that recover on their own aren't
  /// lost. If the factory throws, the stream emits one failure and closes. If
  /// `handle` throws, that error passes through untyped.
  ///
  /// {@endtemplate}
  factory ResultStream.attempt({
    required Stream<S> Function() run,
    required F Function(Object e) handle,
  }) => ResultStream(() {
    final Stream<S> source;
    try {
      source = run();
    } on Object catch (e, s) {
      return Stream.value(Failure(handle(e), e, s));
    }

    return source.transform(
      StreamTransformer.fromHandlers(
        handleData: (data, sink) => sink.add(Success(data)),
        handleError: (e, s, sink) => sink.add(Failure(handle(e), e, s)),
      ),
    );
  });

  /// {@template mallard.result_stream.from_task}
  ///
  /// Creates a result stream that emits the task's [Result], then closes.
  ///
  /// Each run runs the task again, as an inner run (see [Mallard]).
  ///
  /// {@endtemplate}
  factory ResultStream.fromTask(Task<S, F> task) =>
      ResultStream(() => Stream.fromFuture(Future.sync(task.run)));

  /// {@template mallard.result_stream.succeed}
  ///
  /// Creates a result stream that emits one success with the given value,
  /// then closes. For stubbing in tests:
  ///
  /// ```dart
  /// when(() => weatherApi.watchTemperature(any()))
  ///     .thenReturn(ResultStream.succeed(21.5));
  /// ```
  ///
  /// {@endtemplate}
  factory ResultStream.succeed(S value) =>
      ResultStream(() => Stream.value(Success<S, F>(value)));

  /// {@template mallard.result_stream.fail}
  ///
  /// Creates a result stream that emits one failure with the given value and
  /// an optional exception and stack trace, then closes. For stubbing in tests:
  ///
  /// ```dart
  /// when(() => weatherApi.watchTemperature(any()))
  ///     .thenReturn(ResultStream.fail(WeatherError.offline));
  /// ```
  ///
  /// {@endtemplate}
  factory ResultStream.fail(
    F value, [
    Object? exception,
    StackTrace? stackTrace,
  ]) => ResultStream(
    () => Stream.value(Failure<S, F>(value, exception, stackTrace)),
  );

  /// {@template mallard.result_stream.from_results}
  ///
  /// Creates a result stream that emits the given results in order, then
  /// closes. For stubbing in tests:
  ///
  /// ```dart
  /// when(() => weatherApi.watchTemperature(any())).thenReturn(
  ///   ResultStream.fromResults([
  ///     const Success(21.5),
  ///     const Failure(WeatherError.offline),
  ///   ]),
  /// );
  /// ```
  ///
  /// {@endtemplate}
  factory ResultStream.fromResults(Iterable<Result<S, F>> results) =>
      ResultStream(() => Stream.fromIterable(results));

  final Stream<Result<S, F>> Function() _stream;

  /// {@template mallard.result_stream.run}
  ///
  /// Runs the source and returns its stream of [Result]s.
  ///
  /// Every call builds a fresh, independent pipeline, built now rather than on
  /// listen. The output is broadcast exactly when the source is, and cancel,
  /// pause and resume reach the source. This never throws synchronously: if
  /// the factory throws, the output emits that error and closes.
  ///
  /// Reports each result to [Mallard.onStreamSuccess] or
  /// [Mallard.onStreamFailure], unless this is an inner run (see [Mallard]).
  /// If a callback throws, its error is emitted in place of that result.
  ///
  /// {@endtemplate}
  Stream<Result<S, F>> run() => runStream(_stream);

  /// {@template mallard.result_stream.apply}
  ///
  /// Maps each whole [Result].
  ///
  /// {@endtemplate}
  ResultStream<S2, F2> apply<S2, F2>(
    Result<S2, F2> Function(Result<S, F> result) onRun,
  ) => ResultStream(() => run().map(onRun));

  /// {@template mallard.result_stream.then}
  ///
  /// Runs a function that returns a [Result] with each success value. Failures
  /// skip it.
  ///
  /// Steps run one at a time, like [Stream.asyncMap]: the source is paused
  /// while a step runs, and the output keeps input order, failures included.
  ///
  /// {@endtemplate}
  ResultStream<S2, F> then<S2>(
    FutureOr<Result<S2, F>> Function(S success) run,
  ) => ResultStream(
    () => this.run().asyncMap(
      (r) => switch (r) {
        Success(:final value) => run(value),
        final Failure<S, F> f => f.retype(),
      },
    ),
  );

  /// {@template mallard.result_stream.then_attempt}
  ///
  /// Runs a function that may throw with each success value, catching a throw
  /// as [Task.attempt] does. Failures skip it.
  ///
  /// Steps run one at a time, as with [then].
  ///
  /// {@endtemplate}
  ResultStream<S2, F> thenAttempt<S2>({
    required FutureOr<S2> Function(S success) run,
    required F Function(Object e) handle,
  }) =>
      chain((success) => Task.attempt(run: () => run(success), handle: handle));

  /// {@template mallard.result_stream.chain}
  ///
  /// Runs the task built from each success value. Failures skip it.
  ///
  /// Steps run one at a time, as with [then]. Each task is an inner run (see
  /// [Mallard]).
  ///
  /// {@endtemplate}
  ResultStream<S2, F> chain<S2>(Task<S2, F> Function(S success) task) =>
      then((success) => task(success).run());

  /// {@template mallard.result_stream.chain_stream}
  ///
  /// Switches to the result stream built from each success value.
  ///
  /// This is switch-latest: each success cancels the current inner stream and
  /// listens to the new one, and a failure cancels it and is emitted. The
  /// output closes once this stream and the last inner stream have both
  /// closed. Each inner stream is an inner run (see [Mallard]).
  ///
  /// {@endtemplate}
  ResultStream<S2, F> chainStream<S2>(
    ResultStream<S2, F> Function(S success) stream,
  ) => ResultStream(() => _switchLatest(stream));

  /// {@template mallard.result_stream.then_attempt_stream}
  ///
  /// Switches to the plain stream built from each success value, catching its
  /// errors as [ResultStream.attempt] does. Otherwise it behaves like
  /// [chainStream].
  ///
  /// {@endtemplate}
  ResultStream<S2, F> thenAttemptStream<S2>({
    required Stream<S2> Function(S success) run,
    required F Function(Object e) handle,
  }) => chainStream(
    (success) => ResultStream.attempt(run: () => run(success), handle: handle),
  );

  /// {@template mallard.result_stream.combine_with}
  ///
  /// Combines the latest success of this stream and the others with
  /// `combine`.
  ///
  /// This is combine-latest: nothing is emitted until every stream has
  /// emitted, then each new success emits a freshly combined value. Each
  /// failure is emitted once. While any stream's latest result is a failure,
  /// successes from the others are held rather than combined with stale data,
  /// until the failing stream succeeds again. A failure that arrives before
  /// every stream has emitted is emitted straight away.
  ///
  /// The output closes once every stream has closed, or as soon as one closes
  /// without ever emitting. Cancel, pause and resume reach every stream, and
  /// the output is broadcast only if every stream is. Each stream is an inner
  /// run (see [Mallard]).
  ///
  /// To rebuild the streams from each success of an upstream stream, combine
  /// them inside [chainStream].
  ///
  /// {@endtemplate}
  ResultStream<S2, F> combineWith<B, S2>(
    ResultStream<B, F> other, {
    required S2 Function(S a, B b) combine,
  }) => _combineLatest([this, other], (v) => combine(v[0] as S, v[1] as B));

  /// {@macro mallard.result_stream.combine_with}
  ResultStream<S2, F> combineWithTwo<B, C, S2>(
    (ResultStream<B, F>, ResultStream<C, F>) others, {
    required S2 Function(S a, B b, C c) combine,
  }) {
    final (b, c) = others;
    return _combineLatest([
      this,
      b,
      c,
    ], (v) => combine(v[0] as S, v[1] as B, v[2] as C));
  }

  /// {@macro mallard.result_stream.combine_with}
  ResultStream<S2, F> combineWithThree<B, C, D, S2>(
    (ResultStream<B, F>, ResultStream<C, F>, ResultStream<D, F>) others, {
    required S2 Function(S a, B b, C c, D d) combine,
  }) {
    final (b, c, d) = others;
    return _combineLatest([
      this,
      b,
      c,
      d,
    ], (v) => combine(v[0] as S, v[1] as B, v[2] as C, v[3] as D));
  }

  /// {@macro mallard.result_stream.combine_with}
  ResultStream<S2, F> combineWithFour<B, C, D, E, S2>(
    (
      ResultStream<B, F>,
      ResultStream<C, F>,
      ResultStream<D, F>,
      ResultStream<E, F>,
    )
    others, {
    required S2 Function(S a, B b, C c, D d, E e) combine,
  }) {
    final (b, c, d, e) = others;
    return _combineLatest([
      this,
      b,
      c,
      d,
      e,
    ], (v) => combine(v[0] as S, v[1] as B, v[2] as C, v[3] as D, v[4] as E));
  }

  /// {@macro mallard.result_stream.combine_with}
  ResultStream<S2, F> combineWithFive<B, C, D, E, G, S2>(
    (
      ResultStream<B, F>,
      ResultStream<C, F>,
      ResultStream<D, F>,
      ResultStream<E, F>,
      ResultStream<G, F>,
    )
    others, {
    required S2 Function(S a, B b, C c, D d, E e, G g) combine,
  }) {
    final (b, c, d, e, g) = others;
    return _combineLatest(
      [this, b, c, d, e, g],
      (v) => combine(
        v[0] as S,
        v[1] as B,
        v[2] as C,
        v[3] as D,
        v[4] as E,
        v[5] as G,
      ),
    );
  }

  /// {@macro mallard.result.convert_both}
  ResultStream<S2, F2> convertBoth<S2, F2>({
    required S2 Function(S success) onSuccess,
    required F2 Function(F failure) onFailure,
  }) => apply((r) => r.convertBoth(onSuccess: onSuccess, onFailure: onFailure));

  /// {@macro mallard.result.convert}
  ResultStream<S2, F> convert<S2>(S2 Function(S success) onSuccess) =>
      apply((r) => r.convert(onSuccess));

  /// {@macro mallard.result.convert_failure}
  ResultStream<S, F2> convertFailure<F2>(F2 Function(F failure) onFailure) =>
      apply((r) => r.convertFailure(onFailure));

  /// {@macro mallard.result.recover_when}
  ResultStream<S, F> recoverWhen({
    required bool Function(F failure) check,
    required S Function(F failure) then,
  }) => apply((r) => r.recoverWhen(check: check, then: then));

  /// {@macro mallard.result.ensure}
  ResultStream<S, F> ensure({
    required bool Function(S success) check,
    required F Function(S success) otherwise,
  }) => apply((r) => r.ensure(check: check, otherwise: otherwise));

  /// {@template mallard.result_stream.transform}
  ///
  /// Applies a [StreamTransformer] to the results, for stream-shaped behaviour
  /// such as `distinct`, `take` or debouncing.
  ///
  /// {@endtemplate}
  ResultStream<S2, F2> transform<S2, F2>(
    StreamTransformer<Result<S, F>, Result<S2, F2>> transformer,
  ) => ResultStream(() => run().transform(transformer));

  /// {@template mallard.result_stream.until_failure}
  ///
  /// Emits results up to and including the first failure, then closes and
  /// cancels the source. Untyped stream errors don't stop it.
  ///
  /// {@endtemplate}
  ResultStream<S, F> untilFailure() => transform(
    StreamTransformer.fromHandlers(
      handleData: (r, sink) {
        sink.add(r);
        if (r.failed) sink.close();
      },
    ),
  );

  /// {@template mallard.result_stream.restart_when}
  ///
  /// Cancels the source and runs it again when `onFailure` or `onClose`
  /// returns true, such as to reconnect a dropped websocket feed.
  ///
  /// `onFailure` is asked on each failure and `onClose` when the source
  /// closes. Give at least one; a trigger left out never restarts. `attempt`
  /// counts the restarts since the last success. There is no built-in delay,
  /// backoff or limit: `await` a delay in the callback and use `attempt` to
  /// give up.
  ///
  /// With `hideFailure` (the default), the source is paused while `onFailure`
  /// decides. A restart drops the failure and everything after it, so
  /// [Mallard.onStreamFailure] never sees them. Giving up emits the failure
  /// and resumes the source. Without `hideFailure`, the failure is emitted
  /// straight away and events keep flowing while `onFailure` decides.
  ///
  /// One decision runs at a time. Failures that arrive meanwhile don't ask
  /// again: with `hideFailure` they are held and dropped on a restart, and
  /// without it they are emitted. A close waits for the pending decision, then
  /// asks `onClose` unless the stream restarted. A callback that throws emits
  /// an untyped error and counts as false. If the factory throws on a restart,
  /// the stream emits that error and closes. A restart while the listener is
  /// paused runs the source paused. A listener cancelling never restarts, and
  /// untyped stream errors pass through without asking.
  ///
  /// A restart is invisible downstream. On a combined stream it reruns every
  /// source, so restart each source instead, before [combineWith] or inside
  /// [chainStream]. An `onClose` that always returns true without a delay
  /// restarts forever.
  ///
  /// {@endtemplate}
  ResultStream<S, F> restartWhen({
    FutureOr<bool> Function(F failure, int attempt)? onFailure,
    FutureOr<bool> Function(int attempt)? onClose,
    bool hideFailure = true,
  }) {
    assert(
      onFailure != null || onClose != null,
      'restartWhen needs onFailure, onClose or both.',
    );
    return ResultStream(() {
      // Builds through the raw factory rather than [run] so a throwing build
      // closes the stream: through [run] it would become an error stream
      // whose close could restart forever.
      //
      // The latest source, which a new listener listens to.
      Stream<Result<S, F>> current;
      try {
        current = _stream();
      } on Object catch (e, s) {
        return Stream.error(e, s);
      }

      return relay(
        broadcast: current.isBroadcast,
        onListen: (session) => _Restarter(
          session,
          rebuild: () => current = _stream(),
          onFailure: onFailure,
          onClose: onClose,
          hideFailure: hideFailure,
        ).listen(() => current),
      );
    });
  }

  Stream<Result<S2, F>> _switchLatest<S2>(
    ResultStream<S2, F> Function(S success) stream,
  ) {
    final outer = run();

    return relay(
      broadcast: outer.isBroadcast,
      onListen: (session) {
        Lane? inner;
        var outerDone = false;

        void closeIfDone() {
          if (outerDone && inner == null) session.close();
        }

        void cancelInner() {
          unawaited(inner?.cancel());
          inner = null;
        }

        void onSuccess(S success) {
          cancelInner();
          inner = session.listen(
            () => stream(success).run(),
            onData: session.add,
            onDone: () {
              inner = null;
              closeIfDone();
            },
            onBuildError: session.addError,
          );
        }

        session.listen(
          () => outer,
          onData: (r) {
            switch (r) {
              case Success(:final value):
                onSuccess(value);
              case final Failure<S, F> f:
                cancelInner();
                session.add(f.retype());
            }
          },
          onDone: () {
            outerDone = true;
            closeIfDone();
          },
          onBuildError: session.addError,
        );
      },
    );
  }
}

// One listen of a [ResultStream.restartWhen] stream.
class _Restarter<S, F> {
  _Restarter(
    this._session, {
    required this.rebuild,
    required this.onFailure,
    required this.onClose,
    required this.hideFailure,
  });

  final RelaySession<Result<S, F>> _session;

  /// Builds a new source and makes it the one a new listener listens to.
  final Stream<Result<S, F>> Function() rebuild;
  final FutureOr<bool> Function(F failure, int attempt)? onFailure;
  final FutureOr<bool> Function(int attempt)? onClose;
  final bool hideFailure;

  Lane? _lane;
  var _attempt = 0;
  var _deciding = false;
  var _closedWhileDeciding = false;

  void listen(Stream<Result<S, F>> Function() source) {
    _lane = _session.listen(
      source,
      onData: _onData,
      onDone: _onDone,
      onBuildError: (e, s) => _session
        ..addError(e, s)
        ..close(),
    );
  }

  void _restart() {
    _deciding = false;
    _closedWhileDeciding = false;
    _attempt++;
    listen(rebuild);
  }

  // A callback that throws gives an untyped error and counts as false.
  Future<bool> _ask(FutureOr<bool> Function() callback) async {
    try {
      return await callback();
    } on Object catch (e, s) {
      _session.addError(e, s);
      return false;
    }
  }

  void _onData(Result<S, F> r) {
    final onFailure = this.onFailure;

    if (r is! Failure<S, F>) {
      _attempt = 0;
      _session.add(r);
      return;
    }

    if (onFailure == null || _deciding) {
      _session.add(r);
      return;
    }

    _deciding = true;
    if (hideFailure) {
      // Holds the failure and everything after it until the decision.
      _lane!.hold();
    } else {
      _session.add(r);
    }
    unawaited(_decideFailure(r, onFailure));
  }

  Future<void> _decideFailure(
    Failure<S, F> failure,
    FutureOr<bool> Function(F failure, int attempt) onFailure,
  ) async {
    final again = await _ask(() => onFailure(failure.value, _attempt));

    if (again) {
      final lane = _lane;
      _lane = null;
      await lane?.cancel();
      _restart();
      return;
    }

    _deciding = false;
    if (hideFailure) {
      _session.add(failure);
      _lane!.release();
    }
    if (_closedWhileDeciding) {
      _closedWhileDeciding = false;
      _onDone();
    }
  }

  void _onDone() {
    final onClose = this.onClose;

    if (_deciding) {
      _closedWhileDeciding = true;
    } else if (onClose == null) {
      _session.close();
    } else if (_session.isActive) {
      unawaited(_decideClose(onClose));
    }
  }

  Future<void> _decideClose(
    FutureOr<bool> Function(int attempt) onClose,
  ) async {
    _deciding = true;
    final again = await _ask(() => onClose(_attempt));

    if (again) {
      _restart();
    } else {
      _session.close();
    }
  }
}

ResultStream<S, F> _combineLatest<S, F>(
  List<ResultStream<Object?, F>> sources,
  S Function(List<Object?> values) builder,
) => ResultStream(() {
  final streams = [for (final source in sources) source.run()];

  return relay(
    broadcast: streams.every((s) => s.isBroadcast),
    onListen: (session) {
      final latest = List<Result<Object?, F>?>.filled(streams.length, null);
      var closed = 0;

      void onResult(int i, Result<Object?, F> r) {
        latest[i] = r;

        if (r is Failure<Object?, F>) {
          session.add(r.retype());
          return;
        }

        final values = <Object?>[];
        for (final l in latest) {
          if (l is! Success<Object?, F>) return;
          values.add(l.value);
        }

        final S value;
        try {
          value = builder(values);
        } on Object catch (e, s) {
          session.addError(e, s);
          return;
        }
        session.add(Success(value));
      }

      void onDone(int i) {
        closed++;
        if (latest[i] == null || closed == streams.length) session.close();
      }

      for (var i = 0; i < streams.length; i++) {
        session.listen(
          () => streams[i],
          onData: (r) => onResult(i, r),
          onDone: () => onDone(i),
          onBuildError: session.addError,
        );
      }
    },
  );
});
