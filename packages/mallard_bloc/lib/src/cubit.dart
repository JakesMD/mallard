import 'package:bloc/bloc.dart';
import 'package:mallard/mallard.dart';
import 'package:mallard_bloc/mallard_bloc.dart';

/// A mixin that adds request handling capabilities to a Cubit using
/// [TaskBlocState].
mixin TaskCubitMixin<F, S> on Cubit<TaskBlocState<F, S>> {
  /// Performs a request using the provided [task] and updates the Cubit's state
  /// accordingly.
  ///
  /// If a request is already in progress, this method returns immediately
  /// without making a new request.
  Future<void> request(Task<F, S> task) async {
    if (state.isInProgress) return;
    emit(.inProgress(state.result));
    emit(.completed(await task.run()));
  }
}
