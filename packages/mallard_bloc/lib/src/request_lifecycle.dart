import 'package:bloc/bloc.dart';
import 'package:mallard/mallard.dart';
import 'package:mallard_bloc/mallard_bloc.dart';

/// Drives a cubit's [TaskBlocState] through a request: in progress until the
/// first [Result], and restored to the state from before the request if it
/// ends or errors without one.
///
/// Once the cubit is closed, every method is a no-op, so late outcomes need no
/// guard.
///
/// Hidden from the public export; shared by [TaskCubitMixin] and
/// [ResultStreamCubitMixin].
final class RequestLifecycle<S, F> {
  /// Creates a lifecycle for a cubit, which emits through [emit] and reports
  /// untyped errors through [addError].
  RequestLifecycle(
    this._cubit, {
    required void Function(TaskBlocState<S, F> state) emit,
    required void Function(Object error, StackTrace stackTrace) addError,
  }) : _emit = emit,
       _addError = addError;

  final Cubit<TaskBlocState<S, F>> _cubit;
  final void Function(TaskBlocState<S, F> state) _emit;
  final void Function(Object error, StackTrace stackTrace) _addError;

  /// The state to restore if the request ends without a result. It is null
  /// once a result has arrived.
  TaskBlocState<S, F>? _stateBeforeResult;

  /// Emits in progress, keeping the current result.
  ///
  /// Starting again before a result keeps the original state to restore, so a
  /// restore never lands on in progress.
  void start() {
    if (_cubit.isClosed) return;

    _stateBeforeResult ??= _cubit.state;
    _emit(.inProgress(_cubit.state.result));
  }

  /// Emits a completed state for [result].
  void complete(Result<S, F> result) {
    if (_cubit.isClosed) return;

    _stateBeforeResult = null;
    _emit(.completed(result));
  }

  /// Reports an untyped error, and restores the state from before the request
  /// if no result has arrived.
  void error(Object error, StackTrace stackTrace) {
    if (_cubit.isClosed) return;

    _addError(error, stackTrace);
    end();
  }

  /// Restores the state from before the request if no result has arrived.
  void end() {
    if (_cubit.isClosed) return;

    final previousState = _stateBeforeResult;
    _stateBeforeResult = null;
    if (previousState != null) _emit(previousState);
  }
}
