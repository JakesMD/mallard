import 'package:mallard/mallard.dart' as t;
import 'package:mallard/mallard.dart' hide Task;

export 'package:mallard/mallard.dart' hide Result, Task;

/// {@macro mallard.result}
extension type const Res<S, F>._(Result<S, F> _result) {
  /// {@macro mallard.success}
  Res.ok(S value) : this._(Success(value));

  /// {@macro mallard.failure}
  Res.err(F value) : this._(Failure(value));

  /// {@macro mallard.result.resolve}
  T resolve<T>({
    required T Function(S ok) onOk,
    required T Function(F err) onErr,
  }) => _result.resolve(onSuccess: onOk, onFailure: onErr);

  /// {@macro mallard.result.convert_both}
  Res<S2, F2> convertBoth<S2, F2>({
    required S2 Function(S ok) onOk,
    required F2 Function(F err) onErr,
  }) => Res._(_result.convertBoth(onSuccess: onOk, onFailure: onErr));

  /// {@macro mallard.result.convert}
  Res<S2, F> convert<S2>(S2 Function(S ok) onOk) =>
      Res._(_result.convert(onOk));

  /// {@macro mallard.result.convert_failure}
  Res<S, F2> convertErr<F2>(F2 Function(F err) onErr) =>
      Res._(_result.convertFailure(onErr));

  /// {@macro mallard.result.recover_when}
  Res<S, F> recoverWhen({
    required bool Function(F err) check,
    required S Function(F err) then,
  }) => Res._(_result.recoverWhen(check: check, then: then));

  /// {@macro mallard.result.ensure}
  Res<S, F> ensure({
    required bool Function(S ok) check,
    required F Function(S ok) otherwise,
  }) => Res._(_result.ensure(check: check, otherwise: otherwise));

  /// {@macro mallard.result.succeeded}
  bool get isOk => _result.succeeded;

  /// {@macro mallard.result.failed}
  bool get isErr => _result.failed;

  /// {@macro mallard.result.as_success}
  S get asOk => _result.asSuccess;

  /// {@macro mallard.result.as_failure}
  F get asErr => _result.asFailure;
}

/// {@macro mallard.task}
extension type const Task<S, F>._(t.Task<S, F> _task) {
  /// {@macro mallard.task}
  Task(Future<Res<S, F>> Function() run)
    : this._(t.Task(run as Future<Result<S, F>> Function()));

  /// {@macro mallard.task.attempt}
  Task.attempt({
    required Future<S> Function() run,
    required F Function(Object e) handle,
  }) : this._(t.Task.attempt(run: run, handle: handle));

  /// {@macro mallard.task.succeed}
  Task.succeed(S value) : this._(t.Task.succeed(value));

  /// {@macro mallard.task.fail}
  Task.fail(F value, [Object? exception, StackTrace? stack])
    : this._(t.Task.fail(value, exception, stack));

  /// {@macro mallard.task.apply}
  Task<S2, F2> apply<S2, F2>(Res<S2, F2> Function(Res<S, F> re) onRun) =>
      Task._(_task.apply(onRun as Result<S2, F2> Function(Result<S, F>)));

  /// {@macro mallard.task.then}
  Task<S2, F> then<S2>(Future<Res<S2, F>> Function(S ok) run) =>
      Task._(_task.then(run as Future<Result<S2, F>> Function(S)));

  /// {@macro mallard.task.then_attempt}
  Task<S2, F> thenAttempt<S2>({
    required Future<S2> Function(S ok) run,
    required F Function(Object e) handle,
  }) => Task._(_task.thenAttempt(run: run, handle: handle));

  /// {@macro mallard.task.chain}
  Task<S2, F> chain<S2>(Task<S2, F> Function(S ok) task) =>
      Task._(_task.chain(task as t.Task<S2, F> Function(S)));

  /// {@macro mallard.task.convert_both}
  Task<S2, F2> convertBoth<S2, F2>({
    required S2 Function(S ok) onOk,
    required F2 Function(F err) onErr,
  }) => Task._(_task.convertBoth(onSuccess: onOk, onFailure: onErr));

  /// {@macro mallard.task.convert}
  Task<S2, F> convert<S2>(S2 Function(S ok) onOk) =>
      Task._(_task.convert(onOk));

  /// {@macro mallard.task.convert_failure}
  Task<S, F2> convertErr<F2>(F2 Function(F err) onErr) =>
      Task._(_task.convertFailure(onErr));

  /// {@macro mallard.task.recover_when}
  Task<S, F> recoverWhen({
    required bool Function(F err) check,
    required S Function(F err) then,
  }) => Task._(_task.recoverWhen(check: check, then: then));

  /// {@macro mallard.task.ensure}
  Task<S, F> ensure({
    required bool Function(S ok) check,
    required F Function(S ok) otherwise,
  }) => Task._(_task.ensure(check: check, otherwise: otherwise));

  /// {@macro mallard.task.run}
  Future<Res<S, F>> run() => _task.run() as Future<Res<S, F>>;
}
