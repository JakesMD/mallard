import 'dart:async';

/// Builds the output stream of an operator that listens to source streams
/// itself.
///
/// [onListen] runs on every listen of the output, including a listen of a
/// broadcast output after all of its listeners have cancelled, and gets a
/// fresh [RelaySession]. Per-listen state belongs in its locals.
///
/// The output is a broadcast stream when [broadcast] is true. Otherwise the
/// listener's pause and resume reach every live source.
Stream<T> relay<T>({
  required bool broadcast,
  required void Function(RelaySession<T> session) onListen,
}) {
  late final StreamController<T> controller;
  RelaySession<T>? session;

  void listen() => onListen(session = RelaySession._(controller));

  Future<void> cancel() async {
    final ending = session;
    session = null;
    await ending?._cancel();
  }

  controller = broadcast
      ? StreamController.broadcast(onListen: listen, onCancel: cancel)
      : StreamController(
          onListen: listen,
          onPause: () => session?._pause(),
          onResume: () => session?._resume(),
          onCancel: cancel,
        );

  return controller.stream;
}

/// One listen of a relayed output.
///
/// Once the listener cancels or the session closes, the session is no longer
/// active and every method is a no-op, so late asynchronous work needs no
/// guard.
final class RelaySession<T> {
  RelaySession._(this._controller);

  final StreamController<T> _controller;
  final _lanes = <Lane>{};
  final _timers = <Timer>{};
  var _active = true;

  /// Whether the session still reaches the output.
  ///
  /// Only needed to skip work whose outcome the session would drop anyway,
  /// such as asking a user callback.
  bool get isActive => _active;

  /// Emits [event] on the output.
  void add(T event) {
    if (_active) _controller.add(event);
  }

  /// Emits an untyped error on the output.
  void addError(Object error, StackTrace stackTrace) {
    if (_active) _controller.addError(error, stackTrace);
  }

  /// Cancels every lane and closes the output.
  void close() {
    if (!_active) return;
    unawaited(_cancel());
    unawaited(_controller.close());
  }

  /// Builds a source with [build] and listens to it.
  ///
  /// Untyped errors from the source pass through to the output. If [build]
  /// throws, [onBuildError] decides what happens and null is returned. The
  /// lane follows the listener's pause and resume, and starts paused if the
  /// listener is paused.
  Lane? listen<R>(
    Stream<R> Function() build, {
    required void Function(R event) onData,
    required void Function() onDone,
    required void Function(Object error, StackTrace stackTrace) onBuildError,
  }) {
    if (!_active) return null;

    final Stream<R> source;
    try {
      source = build();
    } on Object catch (e, s) {
      onBuildError(e, s);
      return null;
    }

    final lane = Lane._(this);
    lane._sub = source.listen(
      onData,
      onError: addError,
      onDone: () {
        _lanes.remove(lane);
        onDone();
      },
    );
    _lanes.add(lane);
    if (_controller.isPaused) lane._sub.pause();
    return lane;
  }

  /// Calls [callback] after [duration], unless the session ends first.
  void wait(Duration duration, void Function() callback) {
    if (!_active) return;

    late final Timer timer;
    timer = Timer(duration, () {
      _timers.remove(timer);
      callback();
    });
    _timers.add(timer);
  }

  void _pause() {
    for (final lane in _lanes) {
      lane._sub.pause();
    }
  }

  void _resume() {
    for (final lane in _lanes) {
      lane._sub.resume();
    }
  }

  Future<void> _cancel() async {
    _active = false;
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
    final lanes = [..._lanes];
    _lanes.clear();
    await Future.wait(lanes.map((lane) => lane._sub.cancel()));
  }
}

/// One live source subscription inside a [RelaySession].
final class Lane {
  Lane._(this._session);

  final RelaySession<Object?> _session;

  late final StreamSubscription<Object?> _sub;

  /// Stops the source. Its `onDone` never fires.
  Future<void> cancel() {
    _session._lanes.remove(this);
    return _sub.cancel();
  }
}
