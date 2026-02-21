import 'package:mallard/mallard.dart';
import 'package:test/test.dart';
import 'package:test_beautifier/test_beautifier.dart';

void main() {
  final fakeStack = StackTrace.fromString('stack');

  group('Mallard tests', () {
    group('onTaskSuccess', () {
      test(
        requirement(
          When: 'Custom callback is set for onTaskSuccess',
          Then: 'The custom callback should be called with the success value',
        ),
        procedure(() {
          var callbackCalled = false;

          Mallard.onTaskSuccess = (success) {
            expect(success, 1);
            callbackCalled = true;
          };

          Mallard.onTaskSuccess(1);

          expect(callbackCalled, isTrue);
        }),
      );
    });

    group('onTaskFailure', () {
      test(
        requirement(
          When: 'Custom callback is set for onTaskFailure',
          Then:
              '''The custom callback should be called with the failure value, exception, and stack trace''',
        ),
        procedure(() {
          var callbackCalled = false;

          Mallard.onTaskFailure = (failure, exception, stack) {
            expect(failure, 'failure');
            expect(exception, 'Test exception');
            expect(stack, fakeStack);
            callbackCalled = true;
          };

          Mallard.onTaskFailure('failure', 'Test exception', fakeStack);

          expect(callbackCalled, isTrue);
        }),
      );
    });
  });
}
