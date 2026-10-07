import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:mallard/mallard.dart';
import 'package:mallard_bloc/mallard_bloc.dart';
import 'package:test/test.dart';
import 'package:test_beautifier/test_beautifier.dart';

class _StreamCubit extends Cubit<TaskBlocState<int, String>>
    with ResultStreamCubitMixin<int, String> {
  _StreamCubit() : super(.initial());

  final errors = <Object>[];

  @override
  void onError(Object error, StackTrace stackTrace) {
    errors.add(error);
    super.onError(error, stackTrace);
  }
}

void main() {
  group('ResultStreamCubitMixin tests', () {
    late _StreamCubit cubit;
    late List<TaskBlocState<int, String>> states;
    late StreamController<Result<int, String>> controller;

    setUp(() {
      Mallard.onStreamSuccess = (_) {};
      Mallard.onStreamFailure = (_, _, _) {};
      Mallard.onStreamRestart = (_, _, _, _) {};
      cubit = _StreamCubit();
      states = [];
      cubit.stream.listen(states.add);
      controller = StreamController();
    });

    tearDown(() => cubit.close());

    ResultStream<int, String> source() => ResultStream(() => controller.stream);

    test(
      requirement(
        given: 'a stream that emits results',
        whenever: 'it is subscribed',
        then: 'the state goes in progress and then completes for each result',
      ),
      procedure(() async {
        cubit.subscribe(
          ResultStream.fromResults(const [Success(1), Failure('error')]),
        );
        await pumpEventQueue();

        expect(states, [
          TaskBlocState<int, String>.inProgress(),
          TaskBlocState<int, String>.completed(const Success(1)),
          TaskBlocState<int, String>.completed(const Failure('error')),
        ]);
        expect(cubit.isSubscribed, false);
      }),
    );

    test(
      requirement(
        given: 'an open stream whose first event is an untyped error',
        whenever: 'it is subscribed',
        then: 'the error is reported and the state from before is restored',
      ),
      procedure(() async {
        cubit.subscribe(source());
        controller.addError(Exception('untyped'));
        await pumpEventQueue();

        expect(states, [
          TaskBlocState<int, String>.inProgress(),
          TaskBlocState<int, String>.initial(),
        ]);
        expect(cubit.errors, [isA<Exception>()]);
        expect(cubit.isSubscribed, true);
      }),
    );

    test(
      requirement(
        given: 'a restore after an early untyped error',
        whenever: 'the stream later emits a result',
        then: 'the result completes the state',
      ),
      procedure(() async {
        cubit.subscribe(source());
        controller
          ..addError(Exception('untyped'))
          ..add(const Success(1));
        await pumpEventQueue();

        expect(
          states.last,
          TaskBlocState<int, String>.completed(const Success(1)),
        );
      }),
    );

    test(
      requirement(
        given: 'a stream that has emitted a result',
        whenever: 'it emits an untyped error',
        then: 'the error is reported and the completed state is kept',
      ),
      procedure(() async {
        cubit.subscribe(source());
        controller
          ..add(const Success(1))
          ..addError(Exception('untyped'));
        await pumpEventQueue();

        expect(states, [
          TaskBlocState<int, String>.inProgress(),
          TaskBlocState<int, String>.completed(const Success(1)),
        ]);
        expect(cubit.errors, [isA<Exception>()]);
      }),
    );

    test(
      requirement(
        given: 'a stream that closes without a result',
        whenever: 'it is subscribed',
        then: 'the state from before is restored',
      ),
      procedure(() async {
        cubit.subscribe(ResultStream.fromResults(const []));
        await pumpEventQueue();

        expect(states, [
          TaskBlocState<int, String>.inProgress(),
          TaskBlocState<int, String>.initial(),
        ]);
      }),
    );

    test(
      requirement(
        given: 'a subscription with no result yet',
        whenever: 'it is unsubscribed',
        then: 'the state from before is restored and the stream is cancelled',
      ),
      procedure(() async {
        cubit.subscribe(source());
        await cubit.unsubscribe();
        await pumpEventQueue();

        expect(states, [
          TaskBlocState<int, String>.inProgress(),
          TaskBlocState<int, String>.initial(),
        ]);
        expect(controller.hasListener, false);
        expect(cubit.isSubscribed, false);
      }),
    );

    test(
      requirement(
        given: 'a subscription with no result yet',
        whenever: 'another stream is subscribed and closes without a result',
        then: 'the original state is restored, not in progress',
      ),
      procedure(() async {
        cubit
          ..subscribe(source())
          ..subscribe(ResultStream.fromResults(const []));
        await pumpEventQueue();

        expect(states.last, TaskBlocState<int, String>.initial());
        expect(controller.hasListener, false);
      }),
    );

    test(
      requirement(
        given: 'a subscription',
        whenever: 'the cubit is closed',
        then: 'the stream is cancelled',
      ),
      procedure(() async {
        cubit.subscribe(source());
        await cubit.close();

        expect(controller.hasListener, false);
        expect(cubit.errors, isEmpty);
      }),
    );
  });
}
