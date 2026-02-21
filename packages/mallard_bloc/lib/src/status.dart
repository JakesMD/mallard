import 'package:mallard_bloc/mallard_bloc.dart';

/// The status of the [TaskBlocState].
enum TaskBlocStatus {
  /// No request has been made yet.
  initial,

  /// The request is currently in progress.
  inProgress,

  /// The request failed.
  failed,

  /// The request succeeded.
  succeeded,
}
