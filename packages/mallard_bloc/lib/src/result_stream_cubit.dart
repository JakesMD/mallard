import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:mallard/mallard.dart';
import 'package:mallard_bloc/mallard_bloc.dart';
import 'package:mallard_bloc/src/request_lifecycle.dart';

/// Drives a cubit's [TaskBlocState] from a live [ResultStream].
///
/// Use this or [TaskCubitMixin] on a cubit, not both.
mixin ResultStreamCubitMixin<S, F> on Cubit<TaskBlocState<S, F>> {
  late final _lifecycle = RequestLifecycle<S, F>(
    this,
    emit: emit,
    addError: addError,
  );

  StreamSubscription<Result<S, F>>? _subscription;

  /// Whether the cubit is listening to a stream.
  bool get isSubscribed => _subscription != null;

  /// Runs [stream] and emits a completed state for each result, replacing any
  /// live subscription.
  ///
  /// Emits in progress, keeping the current result, until the first result
  /// arrives. If the stream closes or errors before then, the state from
  /// before [subscribe] is restored; after that, the last state is kept.
  /// Untyped errors are reported through [addError], and the subscription
  /// stays live.
  void subscribe(ResultStream<S, F> stream) {
    unawaited(_subscription?.cancel());

    _lifecycle.start();

    _subscription = stream.run().listen(
      _lifecycle.complete,
      onError: _lifecycle.error,
      onDone: () {
        _subscription = null;
        _lifecycle.end();
      },
    );
  }

  /// Cancels the live subscription, if any.
  ///
  /// If no result has arrived since [subscribe], the state from before it is
  /// restored; otherwise the state is kept.
  Future<void> unsubscribe() async {
    final subscription = _subscription;
    if (subscription == null) return;

    _subscription = null;
    _lifecycle.end();
    await subscription.cancel();
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    _subscription = null;
    await super.close();
  }
}
