import 'package:mallard/mallard.dart';

/// Global callbacks that observe every [Task] and [ResultStream] outcome, for
/// logging, analytics or crash reporting.
///
/// Only the outermost run reports. A run started while another task or result
/// stream is running is an inner run and reports nothing itself, whether an
/// operator or your own code started it, and whether or not it is awaited.
/// [onStreamRestart] is the exception. The callbacks fire outside the run, so
/// a run started from a callback is an outermost run.
class Mallard {
  /// Called with the value of each [Success] a task produces.
  static void Function(dynamic success) onTaskSuccess = (_) {};

  /// Called with the value, exception and stack trace of each [Failure] a
  /// task produces.
  static void Function(
    dynamic failure,
    Object? exception,
    StackTrace? stackTrace,
  )
  onTaskFailure = (_, _, _) {};

  /// Called with the value of each [Success] a result stream emits.
  static void Function(dynamic success) onStreamSuccess = (_) {};

  /// Called with the value, exception and stack trace of each [Failure] a
  /// result stream emits.
  static void Function(
    dynamic failure,
    Object? exception,
    StackTrace? stackTrace,
  )
  onStreamFailure = (_, _, _) {};

  /// Called each time [ResultStream.restartWhen] decides to restart, before
  /// any delay, with the failure that caused it, or nulls on close. Fires for
  /// inner runs too.
  static void Function(
    dynamic failure,
    Object? exception,
    StackTrace? stackTrace,
    int attempt,
  )
  onStreamRestart = (_, _, _, _) {};
}
