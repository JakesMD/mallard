import 'package:bloc/bloc.dart';
import 'package:mallard/mallard.dart';
import 'package:mallard_bloc/mallard_bloc.dart';
import 'package:mallard_bloc/src/request_lifecycle.dart';

/// Drives a cubit's [TaskBlocState] through one [Task] at a time.
///
/// Use this or [ResultStreamCubitMixin] on a cubit, not both.
mixin TaskCubitMixin<S, F> on Cubit<TaskBlocState<S, F>> {
  late final _lifecycle = RequestLifecycle<S, F>(
    this,
    emit: emit,
    addError: addError,
  );

  /// Runs [task], emitting in progress and then a completed state for its
  /// result.
  ///
  /// Does nothing while a request is in progress. If [task] throws, the error
  /// is reported through [addError] and the state from before the request is
  /// restored. An outcome that arrives after the cubit closes is dropped.
  Future<void> request(Task<S, F> task) async {
    if (state.isInProgress) return;

    _lifecycle.start();

    try {
      _lifecycle.complete(await task.run());
    } on Object catch (error, stackTrace) {
      // Untyped throws must not leave the cubit stuck in progress.
      _lifecycle.error(error, stackTrace);
    }
  }
}
