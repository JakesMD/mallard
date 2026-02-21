/// The class that handles global Mallard configurations.
class Mallard {
  /// The function called when a task succeeds.
  static void Function(dynamic success) onTaskSuccess = (_) {};

  /// The function called when a task fails.
  static void Function(
    dynamic failure,
    Object? exception,
    StackTrace? stackTrace,
  )
  onTaskFailure = (_, _, _) {};
}
