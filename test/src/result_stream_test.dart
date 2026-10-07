import 'dart:async';

import 'package:mallard/mallard.dart';
import 'package:test/test.dart';
import 'package:test_beautifier/test_beautifier.dart';

void main() {
  final fakeStack = StackTrace.fromString('stack');

  group('ResultStream tests', () {
    setUp(() {
      Mallard.onTaskSuccess = (_) {};
      Mallard.onTaskFailure = (_, _, _) {};
      Mallard.onStreamSuccess = (_) {};
      Mallard.onStreamFailure = (_, _, _) {};
    });

    group('ResultStream.run', () {
      test(
        requirement(
          given: 'a source that emits results',
          whenever: 'the stream is run',
          then: 'the results are emitted in order and the stream closes',
        ),
        procedure(() async {
          final stream = ResultStream<int, String>(
            () => Stream.fromIterable([const Success(1), const Success(2)]),
          );

          await expectLater(
            stream.run(),
            emitsInOrder([
              const Success<int, String>(1),
              const Success<int, String>(2),
              emitsDone,
            ]),
          );
        }),
      );

      test(
        requirement(
          given: 'a source that emits a failure',
          whenever: 'the stream is run',
          then: 'the failure does not end the stream',
        ),
        procedure(() async {
          final stream = ResultStream<int, String>(
            () => Stream.fromIterable([const Failure('x'), const Success(1)]),
          );

          await expectLater(
            stream.run(),
            emitsInOrder([
              const Failure<int, String>('x'),
              const Success<int, String>(1),
              emitsDone,
            ]),
          );
        }),
      );

      test(
        requirement(
          given: 'a factory that throws',
          whenever: 'the stream is run',
          then: 'run does not throw and one error is emitted then close',
        ),
        procedure(() async {
          final stream = ResultStream<int, String>(
            () => throw StateError('boom'),
          );

          late Stream<Result<int, String>> output;
          expect(() => output = stream.run(), returnsNormally);

          await expectLater(
            output,
            emitsInOrder([emitsError(isA<StateError>()), emitsDone]),
          );
        }),
      );

      test(
        requirement(
          given: 'a result stream',
          whenever: 'it is run twice',
          then: 'the factory is called each time',
        ),
        procedure(() async {
          var calls = 0;
          final stream = ResultStream<int, String>(() {
            calls++;
            return Stream.value(Success(calls));
          });

          final first = stream.run();
          final second = stream.run();

          expect(calls, 2);
          expect(await first.toList(), [const Success<int, String>(1)]);
          expect(await second.toList(), [const Success<int, String>(2)]);
        }),
      );

      test(
        requirement(
          given: 'a single-subscription source',
          whenever: 'the stream is run',
          then: 'the output is not broadcast',
        ),
        procedure(() {
          final stream = ResultStream<int, String>(
            () => Stream.fromIterable(const []),
          );

          expect(stream.run().isBroadcast, false);
        }),
      );

      test(
        requirement(
          given: 'a broadcast source',
          whenever: 'the stream is run',
          then: 'the output is broadcast',
        ),
        procedure(() {
          final controller = StreamController<Result<int, String>>.broadcast();
          addTearDown(controller.close);
          final stream = ResultStream<int, String>(() => controller.stream);

          expect(stream.run().isBroadcast, true);
        }),
      );

      test(
        requirement(
          given: 'a source backed by a controller',
          whenever: 'the output is paused, resumed and cancelled',
          then: 'the controller hooks are called',
        ),
        procedure(() async {
          final events = <String>[];
          final controller = StreamController<Result<int, String>>(
            onPause: () => events.add('pause'),
            onResume: () => events.add('resume'),
            onCancel: () => events.add('cancel'),
          );
          final stream = ResultStream<int, String>(() => controller.stream);

          final sub = stream.run().listen((_) {})
            ..pause()
            ..resume();
          await sub.cancel();

          expect(events, ['pause', 'resume', 'cancel']);
        }),
      );

      test(
        requirement(
          given: 'a source that emits a raw error',
          whenever: 'the stream is run',
          then: 'the error passes through and no callback fires',
        ),
        procedure(() async {
          var fired = 0;
          Mallard.onStreamSuccess = (_) => fired++;
          Mallard.onStreamFailure = (_, _, _) => fired++;
          final stream = ResultStream<int, String>(
            () => Stream.error(StateError('boom')),
          );

          await expectLater(
            stream.run(),
            emitsInOrder([emitsError(isA<StateError>()), emitsDone]),
          );
          expect(fired, 0);
        }),
      );
    });

    group('ResultStream.attempt', () {
      test(
        requirement(
          given: 'a source that emits data and error events',
          whenever: 'the stream is run',
          then: 'data become successes and errors become failures',
        ),
        procedure(() async {
          final error = StateError('boom');
          final controller = StreamController<int>();
          final stream = ResultStream<int, String>.attempt(
            run: () => controller.stream,
            handle: (e) => 'handled',
          );

          final results = <Result<int, String>>[];
          final done = stream.run().listen(results.add).asFuture<void>();
          controller
            ..add(1)
            ..addError(error, fakeStack)
            ..add(2);
          await controller.close();
          await done;

          expect(results, hasLength(3));
          expect(results[0], const Success<int, String>(1));
          final failure = results[1] as Failure<int, String>;
          expect(failure.value, 'handled');
          expect(failure.exception, error);
          expect(failure.stackTrace, fakeStack);
          expect(results[2], const Success<int, String>(2));
        }),
      );

      test(
        requirement(
          given: 'a factory that throws',
          whenever: 'the stream is run',
          then: 'one failure is emitted then close',
        ),
        procedure(() async {
          final error = StateError('boom');
          final stream = ResultStream<int, String>.attempt(
            run: () => throw error,
            handle: (e) => 'handled',
          );

          final results = await stream.run().toList();

          expect(results, hasLength(1));
          final failure = results.single as Failure<int, String>;
          expect(failure.value, 'handled');
          expect(failure.exception, error);
        }),
      );

      test(
        requirement(
          given: 'a handle that throws on an error event',
          whenever: 'the stream is run',
          then: 'an untyped error is emitted',
        ),
        procedure(() async {
          final stream = ResultStream<int, String>.attempt(
            run: () => Stream.error('boom'),
            handle: (e) => throw StateError('handle'),
          );

          await expectLater(
            stream.run(),
            emitsInOrder([emitsError(isA<StateError>()), emitsDone]),
          );
        }),
      );

      test(
        requirement(
          given: 'a handle that throws when the factory throws',
          whenever: 'the stream is run',
          then: 'an untyped error is emitted then close',
        ),
        procedure(() async {
          final stream = ResultStream<int, String>.attempt(
            run: () => throw ArgumentError('boom'),
            handle: (e) => throw StateError('handle'),
          );

          await expectLater(
            stream.run(),
            emitsInOrder([emitsError(isA<StateError>()), emitsDone]),
          );
        }),
      );

      test(
        requirement(
          given: 'a broadcast source',
          whenever: 'the stream is run',
          then: 'the output is broadcast',
        ),
        procedure(() {
          final controller = StreamController<int>.broadcast();
          addTearDown(controller.close);
          final stream = ResultStream<int, String>.attempt(
            run: () => controller.stream,
            handle: (e) => 'handled',
          );

          expect(stream.run().isBroadcast, true);
        }),
      );
    });

    group('ResultStream.fromTask', () {
      test(
        requirement(
          given: 'a task',
          whenever: 'the stream is run',
          then: "the task's result is emitted then close",
        ),
        procedure(() async {
          await expectLater(
            ResultStream.fromTask(Task<int, String>.fail('x')).run(),
            emitsInOrder([const Failure<int, String>('x'), emitsDone]),
          );
        }),
      );

      test(
        requirement(
          given: 'a stream from a task',
          whenever: 'it is run twice',
          then: 'the task is run each time',
        ),
        procedure(() async {
          var calls = 0;
          final stream = ResultStream.fromTask(
            Task<int, String>(() async => Success(++calls)),
          );

          expect(await stream.run().toList(), [const Success<int, String>(1)]);
          expect(await stream.run().toList(), [const Success<int, String>(2)]);
        }),
      );

      test(
        requirement(
          given: 'a stream from a task',
          whenever: 'the stream is run',
          then: 'only the stream callback fires',
        ),
        procedure(() async {
          var streamCalls = 0;
          Mallard.onStreamSuccess = (_) => streamCalls++;
          Mallard.onTaskSuccess = (_) => fail('Should not be called');

          await ResultStream.fromTask(
            Task<int, String>.succeed(1),
          ).run().drain<void>();

          expect(streamCalls, 1);
        }),
      );
    });

    group('stubs', () {
      test(
        requirement(
          given: 'ResultStream.succeed',
          whenever: 'the stream is run',
          then: 'one success is emitted then close',
        ),
        procedure(() async {
          await expectLater(
            ResultStream<int, String>.succeed(1).run(),
            emitsInOrder([const Success<int, String>(1), emitsDone]),
          );
        }),
      );

      test(
        requirement(
          given: 'ResultStream.fail',
          whenever: 'the stream is run',
          then: 'one failure with exception and stack is emitted then close',
        ),
        procedure(() async {
          final results = await ResultStream<int, String>.fail(
            'x',
            'ex',
            fakeStack,
          ).run().toList();

          expect(results, hasLength(1));
          final failure = results.single as Failure<int, String>;
          expect(failure.value, 'x');
          expect(failure.exception, 'ex');
          expect(failure.stackTrace, fakeStack);
        }),
      );

      test(
        requirement(
          given: 'ResultStream.fromResults',
          whenever: 'the stream is run',
          then: 'each result is emitted in order then close',
        ),
        procedure(() async {
          await expectLater(
            ResultStream<int, String>.fromResults(const [
              Success(1),
              Failure('x'),
            ]).run(),
            emitsInOrder([
              const Success<int, String>(1),
              const Failure<int, String>('x'),
              emitsDone,
            ]),
          );
        }),
      );

      test(
        requirement(
          given: 'ResultStream.fromResults with no results',
          whenever: 'the stream is run',
          then: 'the stream just closes',
        ),
        procedure(() async {
          await expectLater(
            ResultStream<int, String>.fromResults(const []).run(),
            emitsDone,
          );
        }),
      );
    });

    group('sync operators', () {
      test(
        requirement(
          given: 'a stream of successes and failures',
          whenever: 'convert is applied',
          then: 'each success is converted and failures pass through',
        ),
        procedure(() async {
          final results = await ResultStream<int, String>.fromResults([
            const Success(1),
            const Failure('x'),
            const Success(2),
          ]).convert((s) => s * 10).run().toList();

          expect(results, [
            const Success<int, String>(10),
            const Failure<int, String>('x'),
            const Success<int, String>(20),
          ]);
        }),
      );

      test(
        requirement(
          given: 'a stream of successes and failures',
          whenever: 'convertFailure is applied',
          then: 'each failure is converted',
        ),
        procedure(() async {
          final results = await ResultStream<int, String>.fromResults([
            const Success(1),
            const Failure('x'),
          ]).convertFailure((f) => f.length).run().toList();

          expect(results, [
            const Success<int, int>(1),
            const Failure<int, int>(1),
          ]);
        }),
      );

      test(
        requirement(
          given: 'a stream of successes and failures',
          whenever: 'convertBoth is applied',
          then: 'each event is converted',
        ),
        procedure(() async {
          final results =
              await ResultStream<int, String>.fromResults([
                    const Success(1),
                    const Failure('x'),
                  ])
                  .convertBoth(
                    onSuccess: (s) => '$s',
                    onFailure: (f) => f.length,
                  )
                  .run()
                  .toList();

          expect(results, [
            const Success<String, int>('1'),
            const Failure<String, int>(1),
          ]);
        }),
      );

      test(
        requirement(
          given: 'a stream of successes',
          whenever: 'ensure is applied and one success fails the check',
          then: 'that event becomes a failure and the stream carries on',
        ),
        procedure(() async {
          await expectLater(
            ResultStream<int, String>.fromResults(const [
              Success(1),
              Success(-1),
              Success(2),
            ]).ensure(check: (s) => s > 0, otherwise: (s) => 'neg').run(),
            emitsInOrder([
              const Success<int, String>(1),
              const Failure<int, String>('neg'),
              const Success<int, String>(2),
              emitsDone,
            ]),
          );
        }),
      );

      test(
        requirement(
          given: 'a stream of failures',
          whenever: 'recoverWhen is applied',
          then: 'matching failures are recovered and others pass through',
        ),
        procedure(() async {
          final results =
              await ResultStream<int, String>.fromResults([
                    const Failure('recover'),
                    const Failure('keep'),
                  ])
                  .recoverWhen(check: (f) => f == 'recover', then: (f) => 0)
                  .run()
                  .toList();

          expect(results, [
            const Success<int, String>(0),
            const Failure<int, String>('keep'),
          ]);
        }),
      );

      test(
        requirement(
          given: 'a stream of results',
          whenever: 'apply is applied',
          then: 'each result is transformed',
        ),
        procedure(() async {
          await expectLater(
            ResultStream<int, String>.fromResults(const [
                  Success(1),
                  Failure('x'),
                ])
                .apply<String, int>(
                  (r) => r.succeeded ? const Failure(0) : const Success('ok'),
                )
                .run(),
            emitsInOrder([
              const Failure<String, int>(0),
              const Success<String, int>('ok'),
              emitsDone,
            ]),
          );
        }),
      );

      test(
        requirement(
          given: 'an operator callback that throws on one event',
          whenever: 'the stream is run',
          then: 'an untyped error is emitted and later events still flow',
        ),
        procedure(() async {
          var fired = 0;
          Mallard.onStreamFailure = (_, _, _) => fired++;

          await expectLater(
            ResultStream<int, String>.fromResults(const [
              Success(1),
              Success(2),
              Success(3),
            ]).convert((s) => s == 2 ? throw StateError('boom') : s).run(),
            emitsInOrder([
              const Success<int, String>(1),
              emitsError(isA<StateError>()),
              const Success<int, String>(3),
              emitsDone,
            ]),
          );
          expect(fired, 0);
        }),
      );

      test(
        requirement(
          given: 'a broadcast source',
          whenever: 'an operator is applied',
          then: 'the output is broadcast',
        ),
        procedure(() {
          final controller = StreamController<Result<int, String>>.broadcast();
          addTearDown(controller.close);

          expect(
            ResultStream<int, String>(
              () => controller.stream,
            ).convert((s) => s).run().isBroadcast,
            true,
          );
        }),
      );
    });

    group('ResultStream.transform', () {
      test(
        requirement(
          given: 'a stream transformer',
          whenever: 'it is applied with transform',
          then: 'the output is the transformed stream',
        ),
        procedure(() async {
          final stream =
              ResultStream<int, String>.fromResults(const [
                Success(1),
                Success(1),
                Failure('x'),
              ]).transform(
                StreamTransformer<
                  Result<int, String>,
                  Result<int, String>
                >.fromBind((s) => s.distinct()),
              );

          expect(stream, isA<ResultStream<int, String>>());
          await expectLater(
            stream.run(),
            emitsInOrder([
              const Success<int, String>(1),
              const Failure<int, String>('x'),
              emitsDone,
            ]),
          );
        }),
      );
    });

    group('ResultStream.untilFailure', () {
      test(
        requirement(
          given: 'a source that emits a failure and stays open',
          whenever: 'untilFailure is applied',
          then: 'the failure is emitted, then close, and the source cancelled',
        ),
        procedure(() async {
          var cancelled = false;
          final controller = StreamController<Result<int, String>>(
            onCancel: () => cancelled = true,
          );
          final stream = ResultStream<int, String>(
            () => controller.stream,
          ).untilFailure();

          final output = stream.run();
          controller
            ..add(const Success(1))
            ..add(const Failure('x'))
            ..add(const Success(2));

          await expectLater(
            output,
            emitsInOrder([
              const Success<int, String>(1),
              const Failure<int, String>('x'),
              emitsDone,
            ]),
          );
          expect(cancelled, true);
        }),
      );

      test(
        requirement(
          given: 'a source that emits an untyped error',
          whenever: 'untilFailure is applied',
          then: 'the error passes through and the stream carries on',
        ),
        procedure(() async {
          final controller = StreamController<Result<int, String>>();
          final output = ResultStream<int, String>(
            () => controller.stream,
          ).untilFailure().run();

          controller
            ..addError(StateError('boom'))
            ..add(const Success(1));
          unawaited(controller.close());

          await expectLater(
            output,
            emitsInOrder([
              emitsError(isA<StateError>()),
              const Success<int, String>(1),
              emitsDone,
            ]),
          );
        }),
      );
    });

    group('async operators', () {
      test(
        requirement(
          given: 'a step where later events finish first',
          whenever: 'then is applied',
          then: 'steps run one at a time and output keeps input order',
        ),
        procedure(() async {
          var active = 0;
          var maxActive = 0;

          final results =
              await ResultStream<int, String>.fromResults(const [
                    Success(30),
                    Success(10),
                    Success(0),
                  ])
                  .then((s) async {
                    active++;
                    maxActive = active > maxActive ? active : maxActive;
                    await Future<void>.delayed(Duration(milliseconds: s));
                    active--;
                    return Success<String, String>('$s');
                  })
                  .run()
                  .toList();

          expect(results, [
            const Success<String, String>('30'),
            const Success<String, String>('10'),
            const Success<String, String>('0'),
          ]);
          expect(maxActive, 1);
        }),
      );

      test(
        requirement(
          given: 'a stream with a failure between successes',
          whenever: 'then is applied',
          then: 'the failure keeps its place and skips the step',
        ),
        procedure(() async {
          final calls = <int>[];

          final results =
              await ResultStream<int, String>.fromResults([
                    const Success(1),
                    const Failure('x'),
                    const Success(2),
                  ])
                  .then((s) async {
                    calls.add(s);
                    await Future<void>.delayed(Duration.zero);
                    return Success<int, String>(s * 10);
                  })
                  .run()
                  .toList();

          expect(calls, [1, 2]);
          expect(results, [
            const Success<int, String>(10),
            const Failure<int, String>('x'),
            const Success<int, String>(20),
          ]);
        }),
      );

      test(
        requirement(
          given: 'a source controller',
          whenever: 'a then step is still running',
          then: 'the source is paused until the step completes',
        ),
        procedure(() async {
          final pauses = <bool>[];
          final controller = StreamController<Result<int, String>>();
          final step = Completer<Result<int, String>>();

          final output = ResultStream<int, String>(
            () => controller.stream,
          ).then((s) => step.future).run();

          final results = output.toList();
          controller.add(const Success(1));
          await Future<void>.delayed(Duration.zero);
          pauses.add(controller.isPaused);

          step.complete(const Success(2));
          await Future<void>.delayed(Duration.zero);
          pauses.add(controller.isPaused);

          unawaited(controller.close());
          expect(await results, [const Success<int, String>(2)]);
          expect(pauses, [true, false]);
        }),
      );

      test(
        requirement(
          given: 'a step that throws on one event',
          whenever: 'thenAttempt is applied',
          then: 'that event becomes a failure with the exception and stack',
        ),
        procedure(() async {
          final error = StateError('boom');

          final results =
              await ResultStream<int, String>.fromResults(const [
                    Success(1),
                    Success(2),
                    Success(3),
                  ])
                  .thenAttempt(
                    run: (s) async => s == 2 ? throw error : '$s',
                    handle: (e) => 'handled',
                  )
                  .run()
                  .toList();

          expect(results, hasLength(3));
          expect(results[0], const Success<String, String>('1'));
          expect(results[2], const Success<String, String>('3'));
          final failure = results[1] as Failure<String, String>;
          expect(failure.asFailure, 'handled');
          expect(failure.exception, error);
          expect(failure.stackTrace, isNotNull);
        }),
      );

      test(
        requirement(
          given: 'a stream with a failure',
          whenever: 'thenAttempt is applied',
          then: 'the failure passes through without running the step',
        ),
        procedure(() async {
          final results =
              await ResultStream<int, String>.fromResults([const Failure('x')])
                  .thenAttempt<int>(
                    run: (s) => fail('Should not be called'),
                    handle: (e) => 'handled',
                  )
                  .run()
                  .toList();

          expect(results, [const Failure<int, String>('x')]);
        }),
      );

      test(
        requirement(
          given: 'a stream of a success and a failure',
          whenever: 'chain is applied and the stream is run',
          then: 'no task callback fires and stream ones fire once per event',
        ),
        procedure(() async {
          final successes = <dynamic>[];
          final failures = <dynamic>[];
          Mallard.onStreamSuccess = successes.add;
          Mallard.onStreamFailure = (f, _, _) => failures.add(f);
          Mallard.onTaskSuccess = (_) => fail('Should not be called');
          Mallard.onTaskFailure = (_, _, _) => fail('Should not be called');

          final results =
              await ResultStream<int, String>.fromResults([
                    const Success(1),
                    const Failure('x'),
                    const Success(2),
                  ])
                  .chain((s) {
                    return s == 1
                        ? Task<String, String>.succeed('$s')
                        : Task<String, String>.fail('inner');
                  })
                  .run()
                  .toList();

          expect(results, [
            const Success<String, String>('1'),
            const Failure<String, String>('x'),
            const Failure<String, String>('inner'),
          ]);
          expect(successes, ['1']);
          expect(failures, ['x', 'inner']);
        }),
      );

      test(
        requirement(
          given: 'async operator callbacks that throw on one event',
          whenever: 'the stream is run',
          then: 'an untyped error is emitted and later events still flow',
        ),
        procedure(() async {
          final source = ResultStream<int, String>.fromResults(const [
            Success(1),
            Success(2),
            Success(3),
          ]);
          final expected = emitsInOrder([
            const Success<int, String>(1),
            emitsError(isA<StateError>()),
            const Success<int, String>(3),
            emitsDone,
          ]);

          await expectLater(
            source
                .then<int>(
                  (s) => s == 2 ? throw StateError('boom') : Success(s),
                )
                .run(),
            expected,
          );
          await expectLater(
            source
                .then<int>(
                  (s) async => s == 2 ? throw StateError('boom') : Success(s),
                )
                .run(),
            expected,
          );
          await expectLater(
            source
                .thenAttempt<int>(
                  run: (s) => s == 2 ? throw Exception() : s,
                  handle: (e) => throw StateError('boom'),
                )
                .run(),
            expected,
          );
          await expectLater(
            source
                .chain<int>(
                  (s) => s == 2 ? throw StateError('boom') : Task.succeed(s),
                )
                .run(),
            expected,
          );
        }),
      );

      test(
        requirement(
          given: 'a broadcast source',
          whenever: 'an async operator is applied',
          then: 'the output is broadcast',
        ),
        procedure(() {
          final controller = StreamController<Result<int, String>>.broadcast();
          addTearDown(controller.close);

          expect(
            ResultStream<int, String>(
              () => controller.stream,
            ).then(Success.new).run().isBroadcast,
            true,
          );
        }),
      );
    });

    group('switch-latest operators', () {
      test(
        requirement(
          given: 'a chained stream with a live inner stream',
          whenever: 'the outer stream emits a new success',
          then: 'the old inner stream is cancelled and the new one is used',
        ),
        procedure(() async {
          final outer = StreamController<Result<int, String>>();
          final inners = <int, StreamController<Result<String, String>>>{};
          final cancelled = <int>[];
          final events = <Result<String, String>>[];

          ResultStream<int, String>(() => outer.stream)
              .chainStream(
                (s) => ResultStream(() {
                  final inner = StreamController<Result<String, String>>(
                    onCancel: () => cancelled.add(s),
                  );
                  inners[s] = inner;
                  return inner.stream;
                }),
              )
              .run()
              .listen(events.add);

          outer.add(const Success(1));
          await pumpEventQueue();
          inners[1]!.add(const Success('1a'));
          await pumpEventQueue();
          outer.add(const Success(2));
          await pumpEventQueue();
          inners[1]!.add(const Success('1b'));
          inners[2]!.add(const Success('2a'));
          await pumpEventQueue();

          expect(cancelled, [1]);
          expect(events, [
            const Success<String, String>('1a'),
            const Success<String, String>('2a'),
          ]);
        }),
      );

      test(
        requirement(
          given: 'a chained stream with a live inner stream',
          whenever: 'the outer stream emits a failure',
          then: 'the inner stream is cancelled and the failure is emitted',
        ),
        procedure(() async {
          final outer = StreamController<Result<int, String>>();
          var cancelled = false;
          final events = <Result<String, String>>[];

          ResultStream<int, String>(() => outer.stream)
              .chainStream(
                (s) => ResultStream(
                  () => StreamController<Result<String, String>>(
                    onCancel: () => cancelled = true,
                  ).stream,
                ),
              )
              .run()
              .listen(events.add);

          outer.add(const Success(1));
          await pumpEventQueue();
          outer.add(const Failure('x'));
          await pumpEventQueue();

          expect(cancelled, true);
          expect(events, [const Failure<String, String>('x')]);
        }),
      );

      test(
        requirement(
          given: 'a chained stream with a live inner stream',
          whenever: 'the outer stream closes, then the inner one',
          then: 'the chained stream closes only after both have closed',
        ),
        procedure(() async {
          final outer = StreamController<Result<int, String>>();
          final inner = StreamController<Result<String, String>>();
          var done = false;

          ResultStream<int, String>(() => outer.stream)
              .chainStream((s) => ResultStream(() => inner.stream))
              .run()
              .listen(null, onDone: () => done = true);

          outer.add(const Success(1));
          await pumpEventQueue();
          await outer.close();
          await pumpEventQueue();
          expect(done, false);

          await inner.close();
          await pumpEventQueue();
          expect(done, true);
        }),
      );

      test(
        requirement(
          given: 'a chained stream whose inner stream closes first',
          whenever: 'the outer stream closes',
          then: 'the chained stream closes',
        ),
        procedure(() async {
          final outer = StreamController<Result<int, String>>();

          final output = ResultStream<int, String>(
            () => outer.stream,
          ).chainStream((s) => ResultStream.succeed('$s')).run();

          outer.add(const Success(1));
          unawaited(outer.close());

          await expectLater(
            output,
            emitsInOrder([const Success<String, String>('1'), emitsDone]),
          );
        }),
      );

      test(
        requirement(
          given: 'a chained stream',
          whenever: 'the builder throws for one success',
          then: 'an untyped error is emitted and later events still flow',
        ),
        procedure(() async {
          await expectLater(
            ResultStream<int, String>.fromResults(const [
                  Success(1),
                  Success(2),
                ])
                .chainStream<int>(
                  (s) => s == 1
                      ? throw StateError('boom')
                      : ResultStream.succeed(s),
                )
                .run(),
            emitsInOrder([
              emitsError(isA<StateError>()),
              const Success<int, String>(2),
              emitsDone,
            ]),
          );
        }),
      );

      test(
        requirement(
          given: 'a stream whose inner source emits an error event',
          whenever: 'thenAttemptStream is applied and the stream is run',
          then: 'the error becomes a failure and the inner stream carries on',
        ),
        procedure(() async {
          final results =
              await ResultStream<int, String>.fromResults(const [Success(1)])
                  .thenAttemptStream<int>(
                    run: (s) async* {
                      yield s;
                      yield* Stream<int>.error(Exception('boom'));
                      yield s + 1;
                    },
                    handle: (e) => 'handled',
                  )
                  .run()
                  .toList();

          expect(results, [
            const Success<int, String>(1),
            isA<Failure<int, String>>()
                .having((f) => f.asFailure, 'failure', 'handled')
                .having((f) => f.exception, 'exception', isA<Exception>()),
            const Success<int, String>(2),
          ]);
        }),
      );

      test(
        requirement(
          given: 'a chained stream of a success and a failure',
          whenever: 'the stream is run',
          then: 'stream callbacks fire once per outer event, none for inners',
        ),
        procedure(() async {
          final successes = <dynamic>[];
          final failures = <dynamic>[];
          Mallard.onStreamSuccess = successes.add;
          Mallard.onStreamFailure = (f, _, _) => failures.add(f);
          Mallard.onTaskSuccess = (_) => fail('Should not be called');
          Mallard.onTaskFailure = (_, _, _) => fail('Should not be called');

          await ResultStream<int, String>(() async* {
                yield const Success(1);
                await pumpEventQueue();
                yield const Failure('x');
              })
              .chainStream(
                (s) => ResultStream<String, String>.fromResults([
                  Success('$s'),
                  const Failure('inner'),
                ]),
              )
              .run()
              .drain<void>();

          expect(successes, ['1']);
          expect(failures, ['inner', 'x']);
        }),
      );
    });

    group('Task stream bridges', () {
      test(
        requirement(
          given: 'a successful task',
          whenever: 'chainStream is applied and the stream is run',
          then: 'the inner stream is built from the value',
        ),
        procedure(() async {
          await expectLater(
            Task<int, String>.succeed(1)
                .chainStream(
                  (s) => ResultStream<String, String>.fromResults([
                    Success('$s'),
                    Success('${s + 1}'),
                  ]),
                )
                .run(),
            emitsInOrder([
              const Success<String, String>('1'),
              const Success<String, String>('2'),
              emitsDone,
            ]),
          );
        }),
      );

      test(
        requirement(
          given: 'a failing task',
          whenever: 'chainStream is applied and the stream is run',
          then: 'the failure is emitted and the stream closes without a build',
        ),
        procedure(() async {
          await expectLater(
            Task<int, String>.fail(
              'x',
            ).chainStream<String>((s) => fail('Should not be called')).run(),
            emitsInOrder([const Failure<String, String>('x'), emitsDone]),
          );
        }),
      );

      test(
        requirement(
          given: 'a task bridged to a stream',
          whenever: 'the stream is run twice',
          then: 'the task is run each time',
        ),
        procedure(() async {
          var calls = 0;
          final stream = Task<int, String>(() {
            calls++;
            return Success(calls);
          }).chainStream(ResultStream<int, String>.succeed);

          expect(await stream.run().toList(), [const Success<int, String>(1)]);
          expect(await stream.run().toList(), [const Success<int, String>(2)]);
        }),
      );

      test(
        requirement(
          given: 'a successful and a failing task',
          whenever: 'thenAttemptStream is applied and the streams are run',
          then: 'errors become failures and task failures are emitted',
        ),
        procedure(() async {
          final successes = <dynamic>[];
          final failures = <dynamic>[];
          Mallard.onStreamSuccess = successes.add;
          Mallard.onStreamFailure = (f, _, _) => failures.add(f);
          Mallard.onTaskSuccess = (_) => fail('Should not be called');
          Mallard.onTaskFailure = (_, _, _) => fail('Should not be called');

          final ok = await Task<int, String>.succeed(1)
              .thenAttemptStream<int>(
                run: (s) => Stream.error(Exception('boom')),
                handle: (e) => 'handled',
              )
              .run()
              .toList();
          final err = await Task<int, String>.fail('x')
              .thenAttemptStream<int>(
                run: (s) => fail('Should not be called'),
                handle: (e) => 'handled',
              )
              .run()
              .toList();

          expect(ok, [
            isA<Failure<int, String>>().having(
              (f) => f.asFailure,
              'failure',
              'handled',
            ),
          ]);
          expect(err, [const Failure<int, String>('x')]);
          expect(successes, isEmpty);
          expect(failures, ['handled', 'x']);
        }),
      );
    });

    group('combineWith', () {
      test(
        requirement(
          given: 'a stream with two successes and a failure',
          whenever: 'chainStream is applied with a combineWith inside',
          then: 'each success rebuilds the combined streams',
        ),
        procedure(() async {
          final upstream = StreamController<Result<int, String>>();
          final cancelled = <int>[];
          final events = <Result<int, String>>[];

          ResultStream<int, String> watch(int v) => ResultStream(() {
            late final StreamController<Result<int, String>> c;
            c = StreamController(
              onListen: () => c.add(Success(v)),
              onCancel: () => cancelled.add(v),
            );
            return c.stream;
          });

          ResultStream<int, String>(() => upstream.stream)
              .chainStream(
                (s) => watch(
                  s,
                ).combineWith(watch(s * 10), combine: (v1, v2) => v1 + v2),
              )
              .run()
              .listen(events.add);

          upstream.add(const Success(1));
          await pumpEventQueue();
          upstream.add(const Success(2));
          await pumpEventQueue();
          upstream.add(const Failure('x'));
          await pumpEventQueue();

          expect(events, [
            const Success<int, String>(11),
            const Success<int, String>(22),
            const Failure<int, String>('x'),
          ]);
          expect(cancelled, [1, 10, 2, 20]);
        }),
      );

      test(
        requirement(
          given: 'two combined streams where only one has emitted',
          whenever: 'the other one emits',
          then: 'nothing is emitted before, then each event gives a value',
        ),
        procedure(() async {
          final a = StreamController<Result<int, String>>();
          final b = StreamController<Result<String, String>>();
          final events = <Result<String, String>>[];

          ResultStream<int, String>(() => a.stream)
              .combineWith(
                ResultStream<String, String>(() => b.stream),
                combine: (v1, v2) => '$v1$v2',
              )
              .run()
              .listen(events.add);

          a
            ..add(const Success(1))
            ..add(const Success(2));
          await pumpEventQueue();
          expect(events, isEmpty);

          b.add(const Success('a'));
          await pumpEventQueue();
          a.add(const Success(3));
          await pumpEventQueue();
          b.add(const Success('b'));
          await pumpEventQueue();

          expect(events, [
            const Success<String, String>('2a'),
            const Success<String, String>('3a'),
            const Success<String, String>('3b'),
          ]);
        }),
      );

      test(
        requirement(
          given: 'two combined streams that have both emitted',
          whenever: 'one fails, the other succeeds, then the first recovers',
          then: 'the failure is emitted once and the success is held',
        ),
        procedure(() async {
          final a = StreamController<Result<int, String>>();
          final b = StreamController<Result<int, String>>();
          final events = <Result<int, String>>[];

          ResultStream<int, String>(() => a.stream)
              .combineWith(
                ResultStream<int, String>(() => b.stream),
                combine: (v1, v2) => v1 + v2,
              )
              .run()
              .listen(events.add);

          a.add(const Success(1));
          b.add(const Success(10));
          await pumpEventQueue();
          a.add(const Failure('x'));
          await pumpEventQueue();
          b
            ..add(const Success(20))
            ..add(const Success(30));
          await pumpEventQueue();
          a.add(const Success(2));
          await pumpEventQueue();

          expect(events, [
            const Success<int, String>(11),
            const Failure<int, String>('x'),
            const Success<int, String>(32),
          ]);
        }),
      );

      test(
        requirement(
          given: 'two combined streams where only one has emitted',
          whenever: 'the other one fails',
          then: 'the failure is emitted straight away',
        ),
        procedure(() async {
          final a = StreamController<Result<int, String>>();
          final b = StreamController<Result<int, String>>();
          final events = <Result<int, String>>[];

          ResultStream<int, String>(() => a.stream)
              .combineWith(
                ResultStream<int, String>(() => b.stream),
                combine: (v1, v2) => v1 + v2,
              )
              .run()
              .listen(events.add);

          b.add(const Failure('x'));
          await pumpEventQueue();
          expect(events, [const Failure<int, String>('x')]);

          a.add(const Success(1));
          await pumpEventQueue();
          b.add(const Success(2));
          await pumpEventQueue();
          expect(events, [
            const Failure<int, String>('x'),
            const Success<int, String>(3),
          ]);
        }),
      );

      test(
        requirement(
          given: 'two combined streams that have both emitted',
          whenever: 'they close one after the other',
          then: 'the combined stream closes only after both have closed',
        ),
        procedure(() async {
          final a = StreamController<Result<int, String>>();
          final b = StreamController<Result<int, String>>();
          var done = false;

          ResultStream<int, String>(() => a.stream)
              .combineWith(
                ResultStream<int, String>(() => b.stream),
                combine: (v1, v2) => v1 + v2,
              )
              .run()
              .listen(null, onDone: () => done = true);

          a.add(const Success(1));
          b.add(const Success(2));
          await pumpEventQueue();
          await a.close();
          await pumpEventQueue();
          expect(done, false);

          await b.close();
          await pumpEventQueue();
          expect(done, true);
        }),
      );

      test(
        requirement(
          given: 'two combined streams',
          whenever: 'one closes without ever emitting',
          then: 'the combined stream closes and cancels the other',
        ),
        procedure(() async {
          var cancelled = false;
          final b = StreamController<Result<int, String>>(
            onCancel: () => cancelled = true,
          );

          final output = const ResultStream<int, String>(Stream.empty)
              .combineWith(
                ResultStream<int, String>(() => b.stream),
                combine: (v1, v2) => v1 + v2,
              )
              .run();

          await expectLater(output, emitsDone);
          expect(cancelled, true);
        }),
      );

      test(
        requirement(
          given: 'a combined stream whose builder throws once',
          whenever: 'the sources keep emitting',
          then: 'an untyped error is emitted and later events keep flowing',
        ),
        procedure(() async {
          final output =
              ResultStream<int, String>.fromResults([
                    const Success(1),
                    const Success(2),
                  ])
                  .combineWith(
                    ResultStream<int, String>.succeed(10),
                    combine: (v1, v2) {
                      if (v1 == 1) throw StateError('boom');
                      return v1 + v2;
                    },
                  )
                  .run();

          await expectLater(
            output,
            emitsInOrder([
              emitsError(isA<StateError>()),
              const Success<int, String>(12),
              emitsDone,
            ]),
          );
        }),
      );

      test(
        requirement(
          given: 'a combined stream emitting a success and a failure',
          whenever: 'the stream is run',
          then: 'the callbacks fire once per combined event only',
        ),
        procedure(() async {
          final successes = <dynamic>[];
          final failures = <dynamic>[];
          Mallard.onStreamSuccess = successes.add;
          Mallard.onStreamFailure = (f, _, _) => failures.add(f);

          await ResultStream<int, String>.fromResults([
                const Success(1),
                const Failure('x'),
              ])
              .combineWith(
                ResultStream<int, String>.succeed(10),
                combine: (v1, v2) => v1 + v2,
              )
              .run()
              .drain<void>();

          expect(successes, [11]);
          expect(failures, ['x']);
        }),
      );

      test(
        requirement(
          given: 'three to six succeeding streams',
          whenever: 'they are combined',
          then: 'the builder gets every latest value',
        ),
        procedure(() async {
          ResultStream<int, String> s(int v) => ResultStream.succeed(v);

          expect(
            await s(1)
                .combineWithTwo((
                  s(2),
                  s(3),
                ), combine: (v1, v2, v3) => [v1, v2, v3])
                .run()
                .toList(),
            [
              const Success<List<int>, String>([1, 2, 3]),
            ],
          );
          expect(
            await s(1)
                .combineWithThree((
                  s(2),
                  s(3),
                  s(4),
                ), combine: (v1, v2, v3, v4) => [v1, v2, v3, v4])
                .run()
                .toList(),
            [
              const Success<List<int>, String>([1, 2, 3, 4]),
            ],
          );
          expect(
            await s(1)
                .combineWithFour((
                  s(2),
                  s(3),
                  s(4),
                  s(5),
                ), combine: (v1, v2, v3, v4, v5) => [v1, v2, v3, v4, v5])
                .run()
                .toList(),
            [
              const Success<List<int>, String>([1, 2, 3, 4, 5]),
            ],
          );
          expect(
            await s(1)
                .combineWithFive(
                  (s(2), s(3), s(4), s(5), s(6)),
                  combine: (v1, v2, v3, v4, v5, v6) => [v1, v2, v3, v4, v5, v6],
                )
                .run()
                .toList(),
            [
              const Success<List<int>, String>([1, 2, 3, 4, 5, 6]),
            ],
          );
        }),
      );

      test(
        requirement(
          given: 'combined streams',
          whenever: 'all, or not all, sources are broadcast',
          then: 'the output is broadcast only if every source is',
        ),
        procedure(() {
          final broadcast = ResultStream<int, String>(
            () => StreamController<Result<int, String>>.broadcast().stream,
          );
          final single = ResultStream<int, String>(
            () => Stream.fromIterable([]),
          );

          expect(
            broadcast
                .combineWith(broadcast, combine: (v1, v2) => v1)
                .run()
                .isBroadcast,
            true,
          );
          expect(
            broadcast
                .combineWith(single, combine: (v1, v2) => v1)
                .run()
                .isBroadcast,
            false,
          );
        }),
      );

      test(
        requirement(
          given: 'a combined stream nested inside another combine',
          whenever: 'the stream is run',
          then: 'the values of every source are combined',
        ),
        procedure(() async {
          ResultStream<int, String> s(int v) => ResultStream.succeed(v);

          final inner = s(1).combineWith(s(2), combine: (v1, v2) => v1 + v2);
          final outer = inner.combineWith(s(10), combine: (v1, v2) => v1 * v2);

          expect(await outer.run().toList(), [const Success<int, String>(30)]);
        }),
      );
    });

    group('ResultStream.restartWhen', () {
      // Each run of the source builds a new controller, so restarts can be
      // counted and driven.
      late List<StreamController<Result<int, String>>> sources;
      late ResultStream<int, String> source;

      setUp(() {
        sources = [];
        source = ResultStream(() {
          final controller = StreamController<Result<int, String>>();
          sources.add(controller);
          return controller.stream;
        });
      });

      // Records every event, error and close of the stream as a string.
      List<String> record(
        Stream<Result<int, String>> stream, [
        void Function(StreamSubscription<Result<int, String>>)? onSub,
      ]) {
        final log = <String>[];
        final sub = stream.listen(
          (r) => log.add(
            r.resolve(onSuccess: (s) => 'S$s', onFailure: (f) => 'F$f'),
          ),
          onError: (Object e) => log.add('E$e'),
          onDone: () => log.add('done'),
        );
        onSub?.call(sub);
        return log;
      }

      test(
        requirement(
          given: 'a stream restarted on failure',
          whenever: 'the source fails and onFailure returns true',
          then: 'the failure is hidden and the source is run again',
        ),
        procedure(() async {
          final log = record(
            source.restartWhen(onFailure: (f, attempt) => true).run(),
          );
          await pumpEventQueue();
          sources.last
            ..add(const Success(1))
            ..add(const Failure('x'));
          await pumpEventQueue();
          sources.last.add(const Success(2));
          await pumpEventQueue();

          expect(sources.length, 2);
          expect(log, ['S1', 'S2']);
        }),
      );

      test(
        requirement(
          given: 'a stream restarted on failure',
          whenever: 'the source fails and onFailure returns false',
          then: 'the failure is emitted and the source carries on',
        ),
        procedure(() async {
          final log = record(
            source.restartWhen(onFailure: (f, attempt) => false).run(),
          );
          await pumpEventQueue();
          sources.last
            ..add(const Failure('x'))
            ..add(const Success(1));
          await pumpEventQueue();

          expect(sources.length, 1);
          expect(log, ['Fx', 'S1']);
        }),
      );

      test(
        requirement(
          given: 'a stream restarted on close only',
          whenever: 'the source fails',
          then: 'the failure is emitted and the source is not run again',
        ),
        procedure(() async {
          final log = record(
            source.restartWhen(onClose: (attempt) => true).run(),
          );
          await pumpEventQueue();
          sources.last.add(const Failure('x'));
          await pumpEventQueue();

          expect(sources.length, 1);
          expect(log, ['Fx']);
        }),
      );

      test(
        requirement(
          given: 'a stream restarted on close',
          whenever: 'the source closes until onClose returns false',
          then: 'the source is run again each time, then the stream closes',
        ),
        procedure(() async {
          final attempts = <int>[];
          final log = record(
            source
                .restartWhen(
                  onClose: (attempt) {
                    attempts.add(attempt);
                    return attempt < 2;
                  },
                )
                .run(),
          );
          for (var i = 0; i < 3; i++) {
            await pumpEventQueue();
            await sources.last.close();
          }
          await pumpEventQueue();

          expect(attempts, [0, 1, 2]);
          expect(sources.length, 3);
          expect(log, ['done']);
        }),
      );

      test(
        requirement(
          given: 'a stream restarted on failure only',
          whenever: 'the source closes',
          then: 'the stream closes',
        ),
        procedure(() async {
          final log = record(
            source.restartWhen(onFailure: (f, attempt) => true).run(),
          );
          await pumpEventQueue();
          await sources.last.close();
          await pumpEventQueue();

          expect(sources.length, 1);
          expect(log, ['done']);
        }),
      );

      test(
        requirement(
          given: 'a stream restarted on failure',
          whenever: 'failures follow each other, then a success',
          then: 'attempt counts the restarts and the success resets it',
        ),
        procedure(() async {
          final attempts = <int>[];
          record(
            source
                .restartWhen(
                  onFailure: (f, attempt) {
                    attempts.add(attempt);
                    return true;
                  },
                )
                .run(),
          );
          await pumpEventQueue();
          sources.last.add(const Failure('a'));
          await pumpEventQueue();
          sources.last.add(const Failure('b'));
          await pumpEventQueue();
          sources.last
            ..add(const Success(1))
            ..add(const Failure('c'));
          await pumpEventQueue();

          expect(attempts, [0, 1, 0]);
        }),
      );

      test(
        requirement(
          given: 'a stream hiding failures with a pending decision',
          whenever: 'the source emits more events and onFailure returns false',
          then: 'they are held, then the failure and they are emitted in order',
        ),
        procedure(() async {
          final decision = Completer<bool>();
          final log = record(
            source
                .restartWhen(onFailure: (f, attempt) => decision.future)
                .run(),
          );
          await pumpEventQueue();
          sources.last
            ..add(Failure('x', 'ex', fakeStack))
            ..add(const Success(1))
            ..add(const Success(2));
          await pumpEventQueue();
          expect(log, isEmpty);

          decision.complete(false);
          await pumpEventQueue();
          expect(log, ['Fx', 'S1', 'S2']);
        }),
      );

      test(
        requirement(
          given: 'a stream hiding failures with a pending decision',
          whenever: 'the source emits more events and onFailure returns true',
          then: 'the failure and held events are dropped and it restarts',
        ),
        procedure(() async {
          final decision = Completer<bool>();
          final log = record(
            source
                .restartWhen(onFailure: (f, attempt) => decision.future)
                .run(),
          );
          await pumpEventQueue();
          sources.last
            ..add(const Failure('x'))
            ..add(const Success(1));
          await pumpEventQueue();
          decision.complete(true);
          await pumpEventQueue();

          expect(sources.length, 2);
          expect(log, isEmpty);
        }),
      );

      test(
        requirement(
          given: 'a stream hiding failures',
          whenever: 'one failure is restarted and the next is given up on',
          then: 'only the given-up failure fires onStreamFailure',
        ),
        procedure(() async {
          final failures = <List<Object?>>[];
          Mallard.onStreamFailure = (f, e, s) => failures.add([f, e, s]);
          final events = <Result<int, String>>[];
          source
              .restartWhen(onFailure: (f, attempt) => f == 'retry')
              .run()
              .listen(events.add);
          await pumpEventQueue();
          sources.last.add(const Failure('retry'));
          await pumpEventQueue();
          sources.last.add(Failure('fatal', 'ex', fakeStack));
          await pumpEventQueue();

          expect(events, [Failure<int, String>('fatal', 'ex', fakeStack)]);
          expect(failures, [
            ['fatal', 'ex', fakeStack],
          ]);
        }),
      );

      test(
        requirement(
          given: 'a stream not hiding failures',
          whenever: 'the source fails and onFailure returns true',
          then: 'the failure is emitted straight away and the source restarts',
        ),
        procedure(() async {
          final decision = Completer<bool>();
          final log = record(
            source
                .restartWhen(
                  onFailure: (f, attempt) => decision.future,
                  hideFailure: false,
                )
                .run(),
          );
          await pumpEventQueue();
          sources.last.add(const Failure('x'));
          await pumpEventQueue();
          expect(log, ['Fx']);

          decision.complete(true);
          await pumpEventQueue();
          expect(sources.length, 2);
          expect(log, ['Fx']);
        }),
      );

      test(
        requirement(
          given: 'a stream not hiding failures with a pending decision',
          whenever: 'the source emits more events, including a failure',
          then: 'they flow through and onFailure is not asked again',
        ),
        procedure(() async {
          var asked = 0;
          final decision = Completer<bool>();
          final log = record(
            source
                .restartWhen(
                  onFailure: (f, attempt) {
                    asked++;
                    return decision.future;
                  },
                  hideFailure: false,
                )
                .run(),
          );
          await pumpEventQueue();
          sources.last
            ..add(const Failure('x'))
            ..add(const Success(1))
            ..add(const Failure('y'));
          await pumpEventQueue();

          expect(asked, 1);
          expect(log, ['Fx', 'S1', 'Fy']);
        }),
      );

      test(
        requirement(
          given: 'a pending failure decision',
          whenever: 'the source closes and onFailure returns false',
          then: 'onClose is asked only after the decision',
        ),
        procedure(() async {
          final decision = Completer<bool>();
          final closeAttempts = <int>[];
          final log = record(
            source
                .restartWhen(
                  onFailure: (f, attempt) => decision.future,
                  onClose: (attempt) {
                    closeAttempts.add(attempt);
                    return false;
                  },
                  hideFailure: false,
                )
                .run(),
          );
          await pumpEventQueue();
          sources.last.add(const Failure('x'));
          await sources.last.close();
          await pumpEventQueue();
          expect(closeAttempts, isEmpty);

          decision.complete(false);
          await pumpEventQueue();
          expect(closeAttempts, [0]);
          expect(log, ['Fx', 'done']);
        }),
      );

      test(
        requirement(
          given: 'a pending failure decision',
          whenever: 'the source closes and onFailure returns true',
          then: 'the close is dropped and the source restarts',
        ),
        procedure(() async {
          final decision = Completer<bool>();
          var closeAsked = false;
          final log = record(
            source
                .restartWhen(
                  onFailure: (f, attempt) => decision.future,
                  onClose: (attempt) => closeAsked = true,
                  hideFailure: false,
                )
                .run(),
          );
          await pumpEventQueue();
          sources.last.add(const Failure('x'));
          await sources.last.close();
          await pumpEventQueue();
          decision.complete(true);
          await pumpEventQueue();

          expect(closeAsked, false);
          expect(sources.length, 2);
          expect(log, ['Fx']);
        }),
      );

      test(
        requirement(
          given: 'a stream restarted on failure',
          whenever: 'onFailure throws',
          then: 'an untyped error is emitted and the failure is given up on',
        ),
        procedure(() async {
          final log = record(
            source
                .restartWhen(
                  onFailure: (f, attempt) => throw StateError('boom'),
                )
                .run(),
          );
          await pumpEventQueue();
          sources.last
            ..add(const Failure('x'))
            ..add(const Success(1));
          await pumpEventQueue();

          expect(sources.length, 1);
          expect(log, ['EBad state: boom', 'Fx', 'S1']);
        }),
      );

      test(
        requirement(
          given: 'a stream restarted on close',
          whenever: 'onClose throws',
          then: 'an untyped error is emitted and the stream closes',
        ),
        procedure(() async {
          final log = record(
            source
                .restartWhen(onClose: (attempt) => throw StateError('boom'))
                .run(),
          );
          await pumpEventQueue();
          await sources.last.close();
          await pumpEventQueue();

          expect(sources.length, 1);
          expect(log, ['EBad state: boom', 'done']);
        }),
      );

      test(
        requirement(
          given: 'a source whose factory throws on the second run',
          whenever: 'the stream restarts',
          then: 'an untyped error is emitted and the stream closes',
        ),
        procedure(() async {
          var runs = 0;
          final log = record(
            ResultStream<int, String>(() {
              if (++runs > 1) throw StateError('boom');
              return Stream.value(const Success(1));
            }).restartWhen(onClose: (attempt) => true).run(),
          );
          await pumpEventQueue();

          expect(runs, 2);
          expect(log, ['S1', 'EBad state: boom', 'done']);
        }),
      );

      test(
        requirement(
          given: 'a source whose factory throws on the first run',
          whenever: 'the stream is run',
          then: 'an untyped error is emitted, the stream closes, no restart',
        ),
        procedure(() async {
          var runs = 0;
          final log = record(
            ResultStream<int, String>(() {
              runs++;
              throw StateError('boom');
            }).restartWhen(onClose: (attempt) => true).run(),
          );
          await pumpEventQueue();

          expect(runs, 1);
          expect(log, ['EBad state: boom', 'done']);
        }),
      );

      test(
        requirement(
          given: 'a pending failure decision',
          whenever: 'the listener cancels',
          then: 'the source is not run again and nothing is emitted',
        ),
        procedure(() async {
          final decision = Completer<bool>();
          late StreamSubscription<Result<int, String>> sub;
          final log = record(
            source
                .restartWhen(onFailure: (f, attempt) => decision.future)
                .run(),
            (s) => sub = s,
          );
          await pumpEventQueue();
          sources.last.add(const Failure('x'));
          await pumpEventQueue();
          await sub.cancel();
          decision.complete(true);
          await pumpEventQueue();

          expect(sources.length, 1);
          expect(log, isEmpty);
        }),
      );

      test(
        requirement(
          given: 'a stream restarted on close',
          whenever: 'the listener cancels',
          then: 'onClose is not asked and the source is not run again',
        ),
        procedure(() async {
          var closeAsked = false;
          late StreamSubscription<Result<int, String>> sub;
          record(
            source.restartWhen(onClose: (attempt) => closeAsked = true).run(),
            (s) => sub = s,
          );
          await pumpEventQueue();
          await sub.cancel();
          await pumpEventQueue();

          expect(closeAsked, false);
          expect(sources.length, 1);
        }),
      );

      test(
        requirement(
          given: 'a stream restarted on failure',
          whenever: 'the source emits an untyped error',
          then: 'the error passes through and does not restart',
        ),
        procedure(() async {
          final log = record(
            source.restartWhen(onFailure: (f, attempt) => true).run(),
          );
          await pumpEventQueue();
          sources.last
            ..addError('raw')
            ..add(const Success(1));
          await pumpEventQueue();

          expect(sources.length, 1);
          expect(log, ['Eraw', 'S1']);
        }),
      );

      test(
        requirement(
          given: 'a pending failure decision',
          whenever: 'the listener pauses and the source restarts',
          then: 'the new source is paused until the listener resumes',
        ),
        procedure(() async {
          final decision = Completer<bool>();
          late StreamSubscription<Result<int, String>> sub;
          final log = record(
            source
                .restartWhen(onFailure: (f, attempt) => decision.future)
                .run(),
            (s) => sub = s,
          );
          await pumpEventQueue();
          sources.last.add(const Failure('x'));
          await pumpEventQueue();
          sub.pause();
          decision.complete(true);
          await pumpEventQueue();

          expect(sources.length, 2);
          expect(sources.last.isPaused, true);

          sources.last.add(const Success(1));
          sub.resume();
          await pumpEventQueue();
          expect(sources.last.isPaused, false);
          expect(log, ['S1']);
        }),
      );

      test(
        requirement(
          given: 'a broadcast source restarted on failure',
          whenever: 'two listeners hear a restart',
          then: 'the output is broadcast and both share one restart',
        ),
        procedure(() async {
          final controllers = <StreamController<Result<int, String>>>[];
          final stream = ResultStream<int, String>(() {
            final controller =
                StreamController<Result<int, String>>.broadcast();
            controllers.add(controller);
            return controller.stream;
          }).restartWhen(onFailure: (f, attempt) => true).run();
          final first = record(stream);
          final second = record(stream);

          await pumpEventQueue();
          controllers.last.add(const Success(1));
          await pumpEventQueue();
          controllers.last.add(const Failure('x'));
          await pumpEventQueue();
          controllers.last.add(const Success(2));
          await pumpEventQueue();

          expect(stream.isBroadcast, true);
          expect(controllers.length, 2);
          expect(first, ['S1', 'S2']);
          expect(second, ['S1', 'S2']);
        }),
      );

      test(
        requirement(
          given: 'a restarting inner stream of chainStream',
          whenever: 'the inner stream fails and restarts',
          then: 'no failure is emitted and the restarted values flow on',
        ),
        procedure(() async {
          final outer = StreamController<Result<int, String>>();
          final log = record(
            ResultStream<int, String>(() => outer.stream)
                .chainStream(
                  (s) => source.restartWhen(onFailure: (f, attempt) => true),
                )
                .run(),
          );
          outer.add(const Success(1));
          await pumpEventQueue();
          sources.last
            ..add(const Success(10))
            ..add(const Failure('x'));
          await pumpEventQueue();
          sources.last.add(const Success(11));
          await pumpEventQueue();

          expect(sources.length, 2);
          expect(log, ['S10', 'S11']);
        }),
      );

      test(
        requirement(
          given: 'a restarting source of a combined stream',
          whenever: 'the source fails and restarts',
          then: 'no failure and no stale combine are emitted',
        ),
        procedure(() async {
          final other = StreamController<Result<int, String>>();
          final log = record(
            source
                .restartWhen(onFailure: (f, attempt) => true)
                .combineWith(
                  ResultStream(() => other.stream),
                  combine: (v1, v2) => v1 + v2,
                )
                .run(),
          );
          await pumpEventQueue();
          sources.last.add(const Success(1));
          other.add(const Success(100));
          await pumpEventQueue();
          sources.last.add(const Failure('x'));
          await pumpEventQueue();
          sources.last.add(const Success(2));
          await pumpEventQueue();

          expect(sources.length, 2);
          expect(log, ['S101', 'S102']);
        }),
      );

      test(
        requirement(
          given: 'a result stream',
          whenever: 'restartWhen is applied with no callbacks',
          then: 'an assertion error is thrown',
        ),
        procedure(() {
          expect(source.restartWhen, throwsA(isA<AssertionError>()));
        }),
      );
    });

    // Operators that listen to their sources themselves share one lifecycle,
    // so every one of them is held to the same requirements here.
    group('relayed operators', () {
      // Each case builds the operator from [source], which runs a new source
      // each time it is called, and brings every source live with [prime].
      final cases =
          <
            (
              String,
              ResultStream<int, String> Function(
                ResultStream<int, String> Function() source,
              ),
              void Function(List<StreamController<Result<int, String>>>),
            )
          >[
            ('run', (source) => source(), (_) {}),
            (
              'combineWith',
              (source) =>
                  source().combineWith(source(), combine: (v1, v2) => v1 + v2),
              (_) {},
            ),
            (
              'chainStream',
              (source) => source().chainStream((_) => source()),
              (controllers) => controllers.first.add(const Success(1)),
            ),
            (
              'restartWhen',
              (source) =>
                  source().restartWhen(onFailure: (f, attempt) => false),
              (_) {},
            ),
          ];

      for (final (name, operator, prime) in cases) {
        group(name, () {
          late List<StreamController<Result<int, String>>> controllers;

          ResultStream<int, String> build({bool broadcast = false}) => operator(
            () => ResultStream(() {
              final controller = broadcast
                  ? StreamController<Result<int, String>>.broadcast()
                  : StreamController<Result<int, String>>();
              controllers.add(controller);
              return controller.stream;
            }),
          );

          // Records every event and error of the stream as a string.
          List<String> record(Stream<Result<int, String>> stream) {
            final log = <String>[];
            stream.listen(
              (r) => log.add(
                r.resolve(onSuccess: (s) => 'S$s', onFailure: (f) => 'F$f'),
              ),
              onError: (Object e) => log.add('E$e'),
            );
            return log;
          }

          setUp(() => controllers = []);

          test(
            requirement(
              given: 'a running $name stream with every source live',
              whenever: 'the listener cancels',
              then: 'every source is cancelled',
            ),
            procedure(() async {
              final sub = build().run().listen(null);
              await pumpEventQueue();
              prime(controllers);
              await pumpEventQueue();
              expect(controllers.every((c) => c.hasListener), true);

              await sub.cancel();

              expect(controllers.any((c) => c.hasListener), false);
            }),
          );

          test(
            requirement(
              given: 'a running $name stream with every source live',
              whenever: 'the listener pauses and resumes',
              then: 'every source is paused and resumed',
            ),
            procedure(() async {
              final sub = build().run().listen(null);
              addTearDown(sub.cancel);
              await pumpEventQueue();
              prime(controllers);
              await pumpEventQueue();

              sub.pause();
              expect(controllers.every((c) => c.isPaused), true);

              sub.resume();
              expect(controllers.any((c) => c.isPaused), false);
            }),
          );

          test(
            requirement(
              given: 'a running $name stream',
              whenever: 'a source emits a raw error event',
              then: 'the error passes through as an untyped error',
            ),
            procedure(() async {
              final log = record(build().run());
              await pumpEventQueue();
              prime(controllers);
              await pumpEventQueue();

              controllers.last.addError('boom');
              await pumpEventQueue();

              expect(log, ['Eboom']);
            }),
          );

          test(
            requirement(
              given: 'a $name stream',
              whenever: 'it is run twice',
              then: 'each run builds its sources again',
            ),
            procedure(() async {
              final stream = build()..run();
              final perRun = controllers.length;
              stream.run();

              expect(perRun, greaterThan(0));
              expect(controllers.length, perRun * 2);
            }),
          );

          test(
            requirement(
              given: 'a $name stream',
              whenever: 'its sources are, or are not, broadcast',
              then: 'the output is broadcast exactly when they are',
            ),
            procedure(() async {
              expect(build().run().isBroadcast, false);
              expect(build(broadcast: true).run().isBroadcast, true);
            }),
          );

          test(
            requirement(
              given: 'a $name stream of broadcast sources',
              whenever: 'every listener cancels and a new one listens',
              then: 'the new listener hears the sources',
            ),
            procedure(() async {
              final stream = build(broadcast: true).run();
              await stream.listen(null).cancel();

              final log = record(stream);
              await pumpEventQueue();
              prime(controllers);
              await pumpEventQueue();
              controllers.last.add(const Failure('x'));
              await pumpEventQueue();

              expect(log, ['Fx']);
            }),
          );
        });
      }
    });

    group('callbacks', () {
      test(
        requirement(
          given: 'a stream emitting a success and a failure',
          whenever: 'the stream is run',
          then: 'the stream callbacks fire once each and task ones never',
        ),
        procedure(() async {
          final successes = <dynamic>[];
          final failures = <List<Object?>>[];
          Mallard.onStreamSuccess = successes.add;
          Mallard.onStreamFailure = (f, e, s) => failures.add([f, e, s]);
          Mallard.onTaskSuccess = (_) => fail('Should not be called');
          Mallard.onTaskFailure = (_, _, _) => fail('Should not be called');

          await ResultStream<int, String>.fromResults([
            const Success(1),
            Failure('x', 'ex', fakeStack),
          ]).run().drain<void>();

          expect(successes, [1]);
          expect(failures, [
            ['x', 'ex', fakeStack],
          ]);
        }),
      );

      test(
        requirement(
          given: 'combined streams',
          whenever: 'the combined stream is run',
          then:
              'stream callbacks fire once per combined event, none for inners',
        ),
        procedure(() async {
          final successes = <dynamic>[];
          final failures = <dynamic>[];
          Mallard.onStreamSuccess = successes.add;
          Mallard.onStreamFailure = (f, _, _) => failures.add(f);

          await ResultStream<int, String>.succeed(1)
              .combineWith(
                ResultStream<int, String>.fromResults(const [
                  Success(2),
                  Failure('x'),
                ]),
                combine: (a, b) => a + b,
              )
              .run()
              .drain<void>();

          expect(successes, [3]);
          expect(failures, ['x']);
        }),
      );

      test(
        requirement(
          given: 'a restarting stream that hides a failure',
          whenever: 'the stream is run',
          then: 'stream callbacks fire for emitted results only',
        ),
        procedure(() async {
          final successes = <dynamic>[];
          Mallard.onStreamSuccess = successes.add;
          Mallard.onStreamFailure = (_, _, _) => fail('Should not be called');
          var runs = 0;

          await ResultStream<int, String>(() {
            runs++;
            return Stream.fromIterable([
              if (runs == 1) const Failure('x') else const Success(1),
            ]);
          }).restartWhen(onFailure: (_, _) => true).run().drain<void>();

          expect(successes, [1]);
        }),
      );

      test(
        requirement(
          given: 'a transformed stream',
          whenever: 'the stream is run',
          then: 'stream callbacks fire once per transformed event',
        ),
        procedure(() async {
          final successes = <dynamic>[];
          Mallard.onStreamSuccess = successes.add;

          await ResultStream<int, String>.fromResults(const [
            Success(1),
            Success(1),
            Success(2),
          ]).transform(const _Distinct()).run().drain<void>();

          expect(successes, [1, 2]);
        }),
      );

      test(
        requirement(
          given: 'a stream success callback that throws',
          whenever: 'the stream is run',
          then:
              'the error is emitted in place of the result and later events '
              'still flow',
        ),
        procedure(() async {
          Mallard.onStreamSuccess = (v) {
            if (v == 1) throw StateError('callback');
          };

          await expectLater(
            ResultStream<int, String>.fromResults(const [
              Success(1),
              Success(2),
            ]).run(),
            emitsInOrder([
              emitsError(isA<StateError>()),
              const Success<int, String>(2),
              emitsDone,
            ]),
          );
        }),
      );

      test(
        requirement(
          given: 'a source whose body runs another result stream',
          whenever: 'the outer stream is run',
          then: 'stream callbacks fire once per outer event, none for inner',
        ),
        procedure(() async {
          final successes = <dynamic>[];
          Mallard.onStreamSuccess = successes.add;
          final inner = ResultStream<int, String>.fromResults(const [
            Success(1),
            Success(2),
          ]);

          await ResultStream<int, String>(() async* {
            await for (final r in inner.run()) {
              yield r.convert((v) => v * 10);
            }
          }).run().drain<void>();

          expect(successes, [10, 20]);
        }),
      );

      test(
        requirement(
          given: 'a source whose body runs a task',
          whenever: 'the stream is run',
          then: 'the stream callback fires and the task ones never',
        ),
        procedure(() async {
          final successes = <dynamic>[];
          Mallard.onStreamSuccess = successes.add;
          Mallard.onTaskSuccess = (_) => fail('Should not be called');

          await ResultStream<int, String>(() async* {
            yield await Task<int, String>.succeed(1).run();
          }).run().drain<void>();

          expect(successes, [1]);
        }),
      );

      test(
        requirement(
          given: 'a listener that runs a task for each result',
          whenever: 'the stream is run',
          then: 'the task callback fires, as the listener is outside the run',
        ),
        procedure(() async {
          final taskSuccesses = <dynamic>[];
          Mallard.onTaskSuccess = taskSuccesses.add;

          await ResultStream<int, String>.succeed(1)
              .run()
              .asyncMap((r) => Task<int, String>.succeed(r.asSuccess + 1).run())
              .drain<void>();

          expect(taskSuccesses, [2]);
        }),
      );
    });
  });
}

final class _Distinct<T>
    extends StreamTransformerBase<Result<T, String>, Result<T, String>> {
  const _Distinct();

  @override
  Stream<Result<T, String>> bind(Stream<Result<T, String>> stream) =>
      stream.distinct();
}
