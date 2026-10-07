import 'package:mallard_bloc/mallard_bloc.dart';

/// The status of a [TaskBlocState].
enum TaskBlocStatus {
  /// No request has been made yet.
  initial,

  /// A request is running.
  inProgress,

  /// The request failed.
  failed,

  /// The request succeeded.
  succeeded,
}
