import 'package:equatable/equatable.dart';
import 'package:mallard/mallard.dart';
import 'package:mallard_bloc/mallard_bloc.dart';

/// The state of a cubit driven by a [Task] or [ResultStream]: the [status]
/// of the request and its latest [result].
class TaskBlocState<S, F> with Equatable {
  /// Creates a state with the given [result] and [status].
  TaskBlocState({required this.result, required this.status});

  /// No request has been made yet.
  TaskBlocState.initial([this.result]) : status = TaskBlocStatus.initial;

  /// A request is running. Keeps the previous [result], if any.
  TaskBlocState.inProgress([this.result]) : status = TaskBlocStatus.inProgress;

  /// A request finished with [result]. The [status] is succeeded or failed to
  /// match.
  TaskBlocState.completed(Result<S, F> this.result)
    : status = result.succeeded
          ? TaskBlocStatus.succeeded
          : TaskBlocStatus.failed;

  /// The latest result, or null before the first one.
  final Result<S, F>? result;

  /// The status of the request.
  final TaskBlocStatus status;

  /// The failure value of [result], or null if it isn't a failure.
  F? get failure =>
      result?.resolve(onSuccess: (_) => null, onFailure: (error) => error);

  /// The success value of [result], or null if it isn't a success.
  S? get success =>
      result?.resolve(onSuccess: (value) => value, onFailure: (_) => null);

  /// Whether no request has been made yet.
  bool get isInitial => status == TaskBlocStatus.initial;

  /// Whether a request is running.
  bool get isInProgress => status == TaskBlocStatus.inProgress;

  /// Whether the request succeeded.
  bool get succeeded => status == TaskBlocStatus.succeeded;

  /// Whether the request failed.
  bool get failed => status == TaskBlocStatus.failed;

  @override
  String toString() => switch (status) {
    .initial => 'TaskBlocState<$S, $F>.initial()',
    .inProgress => 'TaskBlocState<$S, $F>.inProgress()',
    .failed => 'TaskBlocState<$S, $F>.failed($failure)',
    .succeeded => 'TaskBlocState<$S, $F>.succeeded($success)',
  };

  @override
  List<Object?> get props => [result, status];
}
