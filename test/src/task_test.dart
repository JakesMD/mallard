import 'package:mallard/mallard.dart';
import 'package:test/test.dart';
import 'package:test_beautifier/test_beautifier.dart';

void main() {
  final fakeStack = StackTrace.fromString('stack');

  group('Task tests', () {
    setUp(() {
      Mallard.onTaskSuccess = (_) {};
      Mallard.onTaskFailure = (_, _, _) {};
    });

    group('Task.attempt', () {
      test(
        requirement(
          given: 'a task that succeeds',
          whenever: 'the task is run',
          then: 'the result is a success',
        ),
        procedure(() async {
          final task = Task.attempt(
            run: () async => 1,
            handle: (_) => fail('Should not be called'),
          );

          final result = await task.run();

          expect(result, const Success<int, Never>(1));
        }),
      );

      test(
        requirement(
          given: 'a task that fails',
          whenever: 'the task is run',
          then: 'the result is a failure',
        ),
        procedure(() async {
          final task = Task.attempt(
            run: () async => throw Exception('error'),
            handle: (e) => 'error',
          );

          final result = await task.run();

          expect(result.failed, true);
          expect(result.asFailure, 'error');
          expect(
            (result as Failure<dynamic, String>).exception,
            isA<Exception>(),
          );
          expect(
            (result as Failure<dynamic, String>).stackTrace,
            isA<StackTrace>(),
          );
        }),
      );
    });

    group('Task.succeed', () {
      test(
        requirement(
          given: 'a task that succeeds with a value',
          whenever: 'the task is run',
          then: 'the result is a success with that value',
        ),
        procedure(() async {
          final task = Task<int, String>.succeed(1);

          final result = await task.run();

          expect(result, const Success<int, String>(1));
        }),
      );
    });

    group('Task.fail', () {
      test(
        requirement(
          given: 'a task that fails with a value',
          whenever: 'the task is run',
          then: 'the result is a failure with that value',
        ),
        procedure(() async {
          final task = Task<int, String>.fail('error', 'error', fakeStack);

          final result = await task.run();

          expect(
            result as Failure<int, String>,
            Failure<int, String>('error', 'error', fakeStack),
          );
        }),
      );
    });

    group('run', () {
      test(
        requirement(
          given: 'a task that succeeds',
          whenever: 'the task is run',
          then: 'the callback is called with the success value',
        ),
        procedure(() async {
          Mallard.onTaskSuccess = (value) {
            expect(value, 1);
          };

          final task = Task<int, String>.succeed(1);

          final result = await task.run();

          expect(result, const Success<int, String>(1));
        }),
      );

      test(
        requirement(
          given: 'a task that fails',
          whenever: 'the task is run',
          then:
              'the callback is called with the failure value, exception, '
              'and stack trace',
        ),
        procedure(() async {
          Mallard.onTaskFailure = (failure, exception, stackTrace) {
            expect(failure, 'error');
            expect(exception, 'error');
            expect(stackTrace, fakeStack);
          };

          final task = Task<int, String>.fail('error', 'error', fakeStack);

          final result = await task.run();

          expect(
            result as Failure<int, String>,
            Failure<int, String>('error', 'error', fakeStack),
          );
        }),
      );
    });

    group('apply', () {
      test(
        requirement(
          given: 'a successful task',
          whenever: 'apply is called on the task with the function',
          then: 'the result is a successful task with the transformed value',
        ),
        procedure(() async {
          final task = Task<int, String>.succeed(
            1,
          ).apply((x) => const Success<String, String>('1'));

          final result = await task.run();

          expect(result, const Success<String, String>('1'));
        }),
      );
    });

    group('then', () {
      test(
        requirement(
          given: 'a successful task',
          whenever: 'then is called on the task with the function',
          then: 'the result is a successful task with the transformed value',
        ),
        procedure(() async {
          final task = Task<int, String>.succeed(
            1,
          ).then((x) async => const Success('1'));

          final result = await task.run();

          expect(result, const Success<String, String>('1'));
        }),
      );

      test(
        requirement(
          given: 'a failed task',
          whenever: 'then is called on the task with the function',
          then: 'the result is a failed task with the original failure',
        ),
        procedure(() async {
          final task = Task<int, String>.fail(
            'error',
            'error',
            fakeStack,
          ).then((x) async => const Success('1'));

          final result = await task.run();

          expect(result, Failure<String, String>('error', 'error', fakeStack));
        }),
      );
    });

    group('thenAttempt', () {
      test(
        requirement(
          given: 'a successful task',
          whenever:
              'thenAttempt is called on the task and the run function succeeds',
          then: 'the result is a successful task with the transformed value',
        ),
        procedure(() async {
          final task = Task<int, String>.succeed(
            1,
          ).thenAttempt(run: (s) async => '1', handle: (e) => 'error');

          final result = await task.run();

          expect(result, const Success<String, String>('1'));
        }),
      );

      test(
        requirement(
          given: 'a successful task',
          whenever:
              'thenAttempt is called on the task and the run function throws',
          then: 'the result is a failed task with the handled failure',
        ),
        procedure(() async {
          final task = Task<int, String>.succeed(1).thenAttempt(
            run: (s) async => throw Exception('error'),
            handle: (e) => 'error',
          );

          final result = await task.run();

          expect(result.failed, true);
          expect(result.asFailure, 'error');
          expect((result as Failure).exception, isA<Exception>());
          expect((result as Failure).stackTrace, isA<StackTrace>());
        }),
      );

      test(
        requirement(
          given: 'a failed task',
          whenever: 'thenAttempt is called on the task',
          then: 'the result is a failed task with the original failure',
        ),
        procedure(() async {
          final task = Task<int, String>.fail(
            'error',
            'error',
            fakeStack,
          ).thenAttempt(run: (s) async => '1', handle: (e) => 'handled error');

          final result = await task.run();

          expect(result, Failure<String, String>('error', 'error', fakeStack));
        }),
      );
    });
    group('chain', () {
      test(
        requirement(
          given: 'a successful task',
          whenever: 'chain is called on the task and succeeds',
          then: 'the result is a successful task with the transformed value',
        ),
        procedure(() async {
          final task = Task<int, String>.succeed(
            1,
          ).chain((x) => Task<String, String>.succeed('1'));

          final result = await task.run();

          expect(result, const Success<String, String>('1'));
        }),
      );

      test(
        requirement(
          given: 'a successful task',
          whenever: 'chain is called on the task and fails',
          then: 'the result is a failed task with the transformed failure',
        ),
        procedure(() async {
          final task = Task<int, String>.succeed(1).chain(
            (x) => Task<String, String>.fail('error', 'error', fakeStack),
          );

          final result = await task.run();

          expect(result, Failure<String, String>('error', 'error', fakeStack));
        }),
      );

      test(
        requirement(
          given: 'a failed task',
          whenever: 'chain is called on the task',
          then: 'the result is a failed task with the original failure',
        ),
        procedure(() async {
          final task = Task<int, String>.fail(
            'error',
            'error',
            fakeStack,
          ).chain((x) => Task<String, String>.succeed('1'));

          final result = await task.run();

          expect(result, Failure<String, String>('error', 'error', fakeStack));
        }),
      );
    });

    group('convertBoth', () {
      test(
        requirement(
          given: 'a successful task',
          whenever: 'convertBoth is called on the task',
          then: 'the result is a successful task with the transformed value',
        ),
        procedure(() async {
          final task = Task<int, Never>.succeed(1).convertBoth(
            onSuccess: (s) => '1',
            onFailure: (f) => fail('Should not be called'),
          );

          final result = await task.run();

          expect(result, const Success<String, Never>('1'));
        }),
      );

      test(
        requirement(
          given: 'a failed task',
          whenever: 'convertBoth is called on the task',
          then: 'the result is a failed task with the transformed failure',
        ),
        procedure(() async {
          final task = Task<Never, String>.fail('error', 'error', fakeStack)
              .convertBoth(
                onSuccess: (s) => fail('Should not be called'),
                onFailure: (f) => 'handled error',
              );

          final result = await task.run();

          expect(
            result,
            Failure<Never, String>('handled error', 'error', fakeStack),
          );
        }),
      );
    });

    group('convert', () {
      test(
        requirement(
          given: 'a successful task',
          whenever: 'convert is called on the task',
          then: 'the result is a successful task with the transformed value',
        ),
        procedure(() async {
          final task = Task<int, String>.succeed(1).convert((s) => '1');

          final result = await task.run();

          expect(result, const Success<String, String>('1'));
        }),
      );

      test(
        requirement(
          given: 'a failed task',
          whenever: 'convert is called on the task',
          then: 'the result is a failed task with the original failure',
        ),
        procedure(() async {
          final task = Task<String, String>.fail(
            'error',
            'error',
            fakeStack,
          ).convert((s) => '1');

          final result = await task.run();

          expect(result, Failure<String, String>('error', 'error', fakeStack));
        }),
      );
    });

    group('convertFailure', () {
      test(
        requirement(
          given: 'a successful task',
          whenever: 'convertFailure is called on the task',
          then: 'the result is a successful task with the original success',
        ),
        procedure(() async {
          final task = Task<int, String>.succeed(
            1,
          ).convertFailure((f) => 'error');

          final result = await task.run();

          expect(result, const Success<int, String>(1));
        }),
      );

      test(
        requirement(
          given: 'a failed task',
          whenever: 'convertFailure is called on the task',
          then: 'the result is a failed task with the transformed failure',
        ),
        procedure(() async {
          final task = Task<String, String>.fail(
            'error',
            'error',
            fakeStack,
          ).convertFailure((f) => 'handled error');

          final result = await task.run();

          expect(
            result,
            Failure<String, String>('handled error', 'error', fakeStack),
          );
        }),
      );
    });

    group('recoverWhen', () {
      test(
        requirement(
          given: 'a failed task',
          whenever:
              'recoverWhen is called on the task and the predicate '
              ' returns true',
          then: 'the result is a successful task with the transformed value',
        ),
        procedure(() async {
          final task = Task<String, String>.fail(
            'error',
            'error',
            fakeStack,
          ).recoverWhen(check: (f) => f == 'error', then: (f) => 'recovered');

          final result = await task.run();

          expect(result, const Success<String, String>('recovered'));
        }),
      );

      test(
        requirement(
          given: 'a failed task',
          whenever:
              'recoverWhen is called on the task and the predicate '
              'returns false',
          then: 'the result is a failed task with the original failure',
        ),
        procedure(() async {
          final task = Task<Never, String>.fail('error', 'error', fakeStack)
              .recoverWhen(
                check: (f) => f == 'other error',
                then: (f) => fail('Should not be called'),
              );

          final result = await task.run();

          expect(result, Failure<Never, String>('error', 'error', fakeStack));
        }),
      );
    });

    group('ensure', () {
      test(
        requirement(
          given: 'a successful task',
          whenever:
              'ensure is called on the task and the predicate returns true',
          then: 'the result is a successful task with the original success',
        ),
        procedure(() async {
          final task = Task<int, Never>.succeed(1).ensure(
            check: (s) => s == 1,
            otherwise: (s) => fail('Should not be called'),
          );

          final result = await task.run();

          expect(result, const Success<int, Never>(1));
        }),
      );

      test(
        requirement(
          given: 'a successful task',
          whenever:
              'ensure is called on the task and the predicate returns false',
          then: 'the result is a failed task with the transformed failure',
        ),
        procedure(() async {
          final task = Task<int, String>.succeed(
            1,
          ).ensure(check: (s) => s == 2, otherwise: (s) => 'error');

          final result = await task.run();

          expect(result, const Failure<int, String>('error'));
        }),
      );
    });
  });
}
