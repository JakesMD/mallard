import 'dart:async';

import 'package:mallard/mallard.dart';
import 'package:mallard/src/relay.dart';

/// Marks the zone of a run in progress.
final _inRun = Object();

/// Whether a run is in progress, which makes any run started now an inner
/// run.
bool get _isInnerRun => Zone.current[_inRun] == true;

/// A zone for the work of an outermost run, in which every run is an inner
/// run.
Zone _runZone() => Zone.current.fork(zoneValues: {_inRun: true});

/// Implements [Task.run]: runs [body] and reports its [Result] to the task
/// callbacks, unless this is an inner run.
///
/// An outermost run runs [body] in a run zone, so every run it starts is an
/// inner run, then fires the callbacks back in the caller's zone. A throw
/// completes the returned future with that error.
///
/// Hidden from the public export.
Future<Result<S, F>> runTask<S, F>(FutureOr<Result<S, F>> Function() body) {
  if (_isInnerRun) return Future.sync(body);

  final outer = Zone.current;
  return _runZone().run(() => Future.sync(body)).then((r) {
    outer.run(() {
      switch (r) {
        case Success(:final value):
          Mallard.onTaskSuccess(value);
        case Failure(:final value, :final exception, :final stackTrace):
          Mallard.onTaskFailure(value, exception, stackTrace);
      }
    });
    return r;
  });
}

/// Implements [ResultStream.run]: builds and listens to the source, and
/// reports each [Result] to the stream callbacks, unless this is an inner run.
///
/// An outermost run builds and listens inside a run zone, so every source an
/// operator builds or listens to later is an inner run too. The callbacks fire
/// back in the caller's zone.
///
/// Hidden from the public export.
Stream<Result<S, F>> runStream<S, F>(Stream<Result<S, F>> Function() build) {
  if (_isInnerRun) return _build(build);

  final outer = Zone.current;
  final zone = _runZone();
  final source = zone.run(() => _build(build));

  return relay(
    broadcast: source.isBroadcast,
    onListen: (session) => zone.run(
      () => session.listen(
        () => source,
        onData: (r) {
          try {
            outer.run(() {
              switch (r) {
                case Success(:final value):
                  Mallard.onStreamSuccess(value);
                case Failure(:final value, :final exception, :final stackTrace):
                  Mallard.onStreamFailure(value, exception, stackTrace);
              }
            });
          } on Object catch (e, s) {
            session.addError(e, s);
            return;
          }
          session.add(r);
        },
        onDone: session.close,
        onBuildError: session.addError,
      ),
    ),
  );
}

/// Calls [build], turning a throw into a stream that emits it and closes.
Stream<Result<S, F>> _build<S, F>(Stream<Result<S, F>> Function() build) {
  try {
    return build();
  } on Object catch (e, s) {
    return Stream.error(e, s);
  }
}
