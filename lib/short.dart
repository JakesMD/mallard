/// Mallard under shorter names: `Res`, `ok`, `err` and friends.
///
/// Built from extension types at no runtime cost. Copy it as a template to
/// name the API your own way.
library;

import 'dart:async';

import 'package:mallard/mallard.dart' as t;
import 'package:mallard/mallard.dart' hide ResultStream, Task;

export 'package:mallard/mallard.dart' hide Result, ResultStream, Task;

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
  Task(FutureOr<Res<S, F>> Function() run)
    : this._(t.Task(run as FutureOr<Result<S, F>> Function()));

  /// {@macro mallard.task.attempt}
  Task.attempt({
    required FutureOr<S> Function() run,
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
  Task<S2, F> then<S2>(FutureOr<Res<S2, F>> Function(S ok) run) =>
      Task._(_task.then(run as FutureOr<Result<S2, F>> Function(S)));

  /// {@macro mallard.task.then_attempt}
  Task<S2, F> thenAttempt<S2>({
    required FutureOr<S2> Function(S ok) run,
    required F Function(Object e) handle,
  }) => Task._(_task.thenAttempt(run: run, handle: handle));

  /// {@macro mallard.task.chain}
  Task<S2, F> chain<S2>(Task<S2, F> Function(S ok) task) =>
      Task._(_task.chain(task as t.Task<S2, F> Function(S)));

  /// {@macro mallard.task.chain_stream}
  ResStream<S2, F> chainStream<S2>(ResStream<S2, F> Function(S ok) stream) =>
      ResStream._(
        _task.chainStream(stream as t.ResultStream<S2, F> Function(S)),
      );

  /// {@macro mallard.task.then_attempt_stream}
  ResStream<S2, F> thenAttemptStream<S2>({
    required Stream<S2> Function(S ok) run,
    required F Function(Object e) handle,
  }) => ResStream._(_task.thenAttemptStream(run: run, handle: handle));

  /// {@macro mallard.result.convert_both}
  Task<S2, F2> convertBoth<S2, F2>({
    required S2 Function(S ok) onOk,
    required F2 Function(F err) onErr,
  }) => Task._(_task.convertBoth(onSuccess: onOk, onFailure: onErr));

  /// {@macro mallard.result.convert}
  Task<S2, F> convert<S2>(S2 Function(S ok) onOk) =>
      Task._(_task.convert(onOk));

  /// {@macro mallard.result.convert_failure}
  Task<S, F2> convertErr<F2>(F2 Function(F err) onErr) =>
      Task._(_task.convertFailure(onErr));

  /// {@macro mallard.result.recover_when}
  Task<S, F> recoverWhen({
    required bool Function(F err) check,
    required S Function(F err) then,
  }) => Task._(_task.recoverWhen(check: check, then: then));

  /// {@macro mallard.result.ensure}
  Task<S, F> ensure({
    required bool Function(S ok) check,
    required F Function(S ok) otherwise,
  }) => Task._(_task.ensure(check: check, otherwise: otherwise));

  /// {@macro mallard.task.run}
  FutureOr<Res<S, F>> run() => _task.run() as FutureOr<Res<S, F>>;
}

/// {@macro mallard.result_stream}
extension type const ResStream<S, F>._(t.ResultStream<S, F> _stream) {
  /// {@macro mallard.result_stream}
  ResStream(Stream<Res<S, F>> Function() stream)
    : this._(t.ResultStream(stream as Stream<Result<S, F>> Function()));

  /// {@macro mallard.result_stream.attempt}
  ResStream.attempt({
    required Stream<S> Function() run,
    required F Function(Object e) handle,
  }) : this._(t.ResultStream.attempt(run: run, handle: handle));

  /// {@macro mallard.result_stream.from_task}
  ResStream.fromTask(Task<S, F> task)
    : this._(t.ResultStream.fromTask(task._task));

  /// {@macro mallard.result_stream.succeed}
  ResStream.succeed(S value) : this._(t.ResultStream.succeed(value));

  /// {@macro mallard.result_stream.fail}
  ResStream.fail(F value, [Object? exception, StackTrace? stack])
    : this._(t.ResultStream.fail(value, exception, stack));

  /// {@macro mallard.result_stream.from_results}
  ResStream.fromResults(Iterable<Res<S, F>> results)
    : this._(t.ResultStream.fromResults(results as Iterable<Result<S, F>>));

  /// {@macro mallard.result_stream.apply}
  ResStream<S2, F2> apply<S2, F2>(Res<S2, F2> Function(Res<S, F> re) onRun) =>
      ResStream._(
        _stream.apply(onRun as Result<S2, F2> Function(Result<S, F>)),
      );

  /// {@macro mallard.result_stream.then}
  ResStream<S2, F> then<S2>(FutureOr<Res<S2, F>> Function(S ok) run) =>
      ResStream._(_stream.then(run as FutureOr<Result<S2, F>> Function(S)));

  /// {@macro mallard.result_stream.then_attempt}
  ResStream<S2, F> thenAttempt<S2>({
    required FutureOr<S2> Function(S ok) run,
    required F Function(Object e) handle,
  }) => ResStream._(_stream.thenAttempt(run: run, handle: handle));

  /// {@macro mallard.result_stream.chain}
  ResStream<S2, F> chain<S2>(Task<S2, F> Function(S ok) task) =>
      ResStream._(_stream.chain(task as t.Task<S2, F> Function(S)));

  /// {@macro mallard.result_stream.chain_stream}
  ResStream<S2, F> chainStream<S2>(ResStream<S2, F> Function(S ok) stream) =>
      ResStream._(
        _stream.chainStream(stream as t.ResultStream<S2, F> Function(S)),
      );

  /// {@macro mallard.result_stream.then_attempt_stream}
  ResStream<S2, F> thenAttemptStream<S2>({
    required Stream<S2> Function(S ok) run,
    required F Function(Object e) handle,
  }) => ResStream._(_stream.thenAttemptStream(run: run, handle: handle));

  /// {@macro mallard.result_stream.combine_with}
  ResStream<S2, F> combineWith<B, S2>(
    ResStream<B, F> other, {
    required S2 Function(S a, B b) combine,
  }) => ResStream._(_stream.combineWith(other._stream, combine: combine));

  /// {@macro mallard.result_stream.combine_with}
  ResStream<S2, F> combineWithTwo<B, C, S2>(
    (ResStream<B, F>, ResStream<C, F>) others, {
    required S2 Function(S a, B b, C c) combine,
  }) => ResStream._(
    _stream.combineWithTwo(
      others as (t.ResultStream<B, F>, t.ResultStream<C, F>),
      combine: combine,
    ),
  );

  /// {@macro mallard.result_stream.combine_with}
  ResStream<S2, F> combineWithThree<B, C, D, S2>(
    (ResStream<B, F>, ResStream<C, F>, ResStream<D, F>) others, {
    required S2 Function(S a, B b, C c, D d) combine,
  }) => ResStream._(
    _stream.combineWithThree(
      others
          as (t.ResultStream<B, F>, t.ResultStream<C, F>, t.ResultStream<D, F>),
      combine: combine,
    ),
  );

  /// {@macro mallard.result_stream.combine_with}
  ResStream<S2, F> combineWithFour<B, C, D, E, S2>(
    (ResStream<B, F>, ResStream<C, F>, ResStream<D, F>, ResStream<E, F>)
    others, {
    required S2 Function(S a, B b, C c, D d, E e) combine,
  }) => ResStream._(
    _stream.combineWithFour(
      others
          as (
            t.ResultStream<B, F>,
            t.ResultStream<C, F>,
            t.ResultStream<D, F>,
            t.ResultStream<E, F>,
          ),
      combine: combine,
    ),
  );

  /// {@macro mallard.result_stream.combine_with}
  ResStream<S2, F> combineWithFive<B, C, D, E, G, S2>(
    (
      ResStream<B, F>,
      ResStream<C, F>,
      ResStream<D, F>,
      ResStream<E, F>,
      ResStream<G, F>,
    )
    others, {
    required S2 Function(S a, B b, C c, D d, E e, G g) combine,
  }) => ResStream._(
    _stream.combineWithFive(
      others
          as (
            t.ResultStream<B, F>,
            t.ResultStream<C, F>,
            t.ResultStream<D, F>,
            t.ResultStream<E, F>,
            t.ResultStream<G, F>,
          ),
      combine: combine,
    ),
  );

  /// {@macro mallard.result.convert_both}
  ResStream<S2, F2> convertBoth<S2, F2>({
    required S2 Function(S ok) onOk,
    required F2 Function(F err) onErr,
  }) => ResStream._(_stream.convertBoth(onSuccess: onOk, onFailure: onErr));

  /// {@macro mallard.result.convert}
  ResStream<S2, F> convert<S2>(S2 Function(S ok) onOk) =>
      ResStream._(_stream.convert(onOk));

  /// {@macro mallard.result.convert_failure}
  ResStream<S, F2> convertErr<F2>(F2 Function(F err) onErr) =>
      ResStream._(_stream.convertFailure(onErr));

  /// {@macro mallard.result.recover_when}
  ResStream<S, F> recoverWhen({
    required bool Function(F err) check,
    required S Function(F err) then,
  }) => ResStream._(_stream.recoverWhen(check: check, then: then));

  /// {@macro mallard.result.ensure}
  ResStream<S, F> ensure({
    required bool Function(S ok) check,
    required F Function(S ok) otherwise,
  }) => ResStream._(_stream.ensure(check: check, otherwise: otherwise));

  /// {@macro mallard.result_stream.transform}
  ResStream<S2, F2> transform<S2, F2>(
    StreamTransformer<Res<S, F>, Res<S2, F2>> transformer,
  ) => ResStream._(
    _stream.transform(
      transformer as StreamTransformer<Result<S, F>, Result<S2, F2>>,
    ),
  );

  /// {@macro mallard.result_stream.until_failure}
  ResStream<S, F> untilErr() => ResStream._(_stream.untilFailure());

  /// {@macro mallard.result_stream.restart_when}
  ResStream<S, F> restartWhen({
    bool Function(F err, int attempt)? onErr,
    bool Function(int attempt)? onClose,
    Duration Function(int attempt)? delay,
    bool hideErr = true,
  }) => ResStream._(
    _stream.restartWhen(
      onFailure: onErr,
      onClose: onClose,
      delay: delay,
      hideFailure: hideErr,
    ),
  );

  /// {@macro mallard.result_stream.run}
  Stream<Res<S, F>> run() => _stream.run() as Stream<Res<S, F>>;
}
