import 'package:equatable/equatable.dart';
import 'package:mallard/mallard.dart';
import 'package:mallard_bloc/mallard_bloc.dart';

/// {@template TaskBlocState}
///
/// A state class for managing the status and result of a request in a bloc or
/// cubit.
///
/// It holds the [result] of the request, which can be either a success of type
/// [S] or a failure of type [F], and the current [status] of the request.
///
/// Provides convenience getters to check the state of the request and to access
/// the failure or success values.
///
/// {@endtemplate}
class TaskBlocState<S, F> with EquatableMixin {
  /// {@macro TaskBlocState}
  TaskBlocState({required this.result, required this.status});

  /// {@macro TaskBlocState}
  ///
  /// The initial state. It sets [status] to [TaskBlocStatus.initial].
  TaskBlocState.initial([this.result]) : status = TaskBlocStatus.initial;

  /// {@macro TaskBlocState}
  ///
  /// The in progress state. It sets [status] to [TaskBlocStatus.inProgress].
  TaskBlocState.inProgress([this.result]) : status = TaskBlocStatus.inProgress;

  /// {@macro TaskBlocState}
  ///
  /// The completed state. It sets [status] to [TaskBlocStatus.failed] or
  /// [TaskBlocStatus.succeeded] based on the result.
  TaskBlocState.completed(Result<S, F> this.result)
    : status = result.succeeded
          ? TaskBlocStatus.succeeded
          : TaskBlocStatus.failed;

  /// The outcome of the request if completed.
  final Result<S, F>? result;

  /// The status of the request.
  final TaskBlocStatus status;

  /// The failure value of the request. Returns null if the request has not
  /// failed.
  F? get failure =>
      result?.resolve(onSuccess: (_) => null, onFailure: (error) => error);

  /// The success value of the request. Returns null if the request has not
  /// succeeded.
  S? get success =>
      result?.resolve(onSuccess: (value) => value, onFailure: (_) => null);

  /// Returns true if the request has not yet been made.
  bool get isInitial => status == TaskBlocStatus.initial;

  /// Returns true if the request is in progress.
  bool get isInProgress => status == TaskBlocStatus.inProgress;

  /// Returns true if the request succeeded.
  bool get succeeded => status == TaskBlocStatus.succeeded;

  /// Returns true if the request failed.
  bool get failed => status == TaskBlocStatus.failed;

  @override
  String toString() => switch (status) {
    .initial => 'TaskBlocState<$F, $S>.initial()',
    .inProgress => 'TaskBlocState<$F, $S>.inProgress()',
    .failed => 'TaskBlocState<$F, $S>.failed($failure)',
    .succeeded => 'TaskBlocState<$F, $S>.succeeded($success)',
  };

  @override
  List<Object?> get props => [result, status];
}
