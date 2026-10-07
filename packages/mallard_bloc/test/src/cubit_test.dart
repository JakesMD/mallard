import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:mallard/mallard.dart';
import 'package:mallard_bloc/mallard_bloc.dart';
import 'package:test/test.dart';
import 'package:test_beautifier/test_beautifier.dart';

class _TaskCubit extends Cubit<TaskBlocState<int, String>>
    with TaskCubitMixin<int, String> {
  _TaskCubit() : super(.initial());

  final errors = <Object>[];

  @override
  void onError(Object error, StackTrace stackTrace) {
    errors.add(error);
    super.onError(error, stackTrace);
  }
}

void main() {
  group('TaskCubitMixin tests', () {
    late _TaskCubit cubit;
    late List<TaskBlocState<int, String>> states;

    setUp(() {
      Mallard.onTaskSuccess = (_) {};
      Mallard.onTaskFailure = (_, _, _) {};
      cubit = _TaskCubit();
      states = [];
      cubit.stream.listen(states.add);
    });

    tearDown(() => cubit.close());

    test(
      requirement(
        given: 'a task that succeeds',
        whenever: 'it is requested',
        then: 'the state goes in progress and then succeeded',
      ),
      procedure(() async {
        await cubit.request(Task.succeed(1));
        await pumpEventQueue();

        expect(states, [
          TaskBlocState<int, String>.inProgress(),
          TaskBlocState<int, String>.completed(const Success(1)),
        ]);
      }),
    );

    test(
      requirement(
        given: 'a completed state and a task that throws an untyped error',
        whenever: 'it is requested',
        then: 'the error is reported and the completed state is restored',
      ),
      procedure(() async {
        await cubit.request(Task.succeed(1));
        await cubit.request(Task(() => throw Exception('untyped')));
        await pumpEventQueue();

        expect(
          states.last,
          TaskBlocState<int, String>.completed(const Success(1)),
        );
        expect(cubit.errors, [isA<Exception>()]);
      }),
    );

    test(
      requirement(
        given: 'a request in flight',
        whenever: 'another task is requested',
        then: 'the second task is ignored',
      ),
      procedure(() async {
        final completer = Completer<Result<int, String>>();

        final first = cubit.request(Task(() => completer.future));
        await cubit.request(Task(() => fail('Should not be called')));
        completer.complete(const Failure('error'));
        await first;
        await pumpEventQueue();

        expect(states, [
          TaskBlocState<int, String>.inProgress(),
          TaskBlocState<int, String>.completed(const Failure('error')),
        ]);
      }),
    );

    test(
      requirement(
        given: 'a request',
        whenever: 'it completes',
        then: 'the task callbacks fire, not the stream callbacks',
      ),
      procedure(() async {
        var taskCalls = 0;
        Mallard.onTaskSuccess = (_) => taskCalls++;
        Mallard.onStreamSuccess = (_) => fail('Should not be called');

        await cubit.request(Task.succeed(1));

        expect(taskCalls, 1);
      }),
    );

    test(
      requirement(
        given: 'a request in flight',
        whenever: 'the cubit is closed before the task completes',
        then: 'the late result is dropped and the request completes normally',
      ),
      procedure(() async {
        final completer = Completer<Result<int, String>>();

        final request = cubit.request(Task(() => completer.future));
        await cubit.close();
        completer.complete(const Success(1));

        await expectLater(request, completes);
        expect(cubit.errors, isEmpty);
      }),
    );

    test(
      requirement(
        given: 'a request in flight',
        whenever: 'the cubit is closed and then the task throws',
        then: 'the error is dropped and the request completes normally',
      ),
      procedure(() async {
        final completer = Completer<Result<int, String>>();

        final request = cubit.request(Task(() => completer.future));
        await cubit.close();
        completer.completeError(Exception('late'));

        await expectLater(request, completes);
        expect(cubit.errors, isEmpty);
      }),
    );
  });
}
