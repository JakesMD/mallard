import 'package:mallard/mallard.dart';
import 'package:test/test.dart';
import 'package:test_beautifier/test_beautifier.dart';

void main() {
  final fakeStack = StackTrace.fromString('stack');

  group('Result tests', () {
    group('resolve', () {
      test(
        requirement(
          Given: 'a successful result',
          When: 'the result is resolved',
          Then: 'the success function is called',
        ),
        procedure(() {
          final result = const Success<int, dynamic>(1).resolve(
            onFailure: (_) => fail('Should not be called'),
            onSuccess: (value) => value,
          );

          expect(result, 1);
        }),
      );

      test(
        requirement(
          Given: 'a failed result',
          When: 'the result is resolved',
          Then: 'the failure function is called',
        ),
        procedure(() {
          final result = const Failure<int, String>('error').resolve(
            onFailure: (error) => error,
            onSuccess: (_) => fail('Should not be called'),
          );

          expect(result, 'error');
        }),
      );
    });

    group('convertBoth', () {
      test(
        requirement(
          Given: 'a successful result',
          When: 'the result is converted',
          Then: 'the success function is called',
        ),
        procedure(() {
          final result = const Success<int, dynamic>(1).convertBoth(
            onFailure: (_) => fail('Should not be called'),
            onSuccess: (value) => value.toString(),
          );

          expect(result, const Success<String, Never>('1'));
        }),
      );

      test(
        requirement(
          Given: 'a failed result',
          When: 'the result is converted',
          Then: 'the failure function is called',
        ),
        procedure(() {
          final result = Failure<int, String>('error', 1, fakeStack)
              .convertBoth(
                onFailure: (error) => error.toUpperCase(),
                onSuccess: (_) => fail('Should not be called'),
              );

          expect(result, Failure<Never, String>('ERROR', 1, fakeStack));
        }),
      );
    });

    group('convert', () {
      test(
        requirement(
          Given: 'a successful result',
          When: 'the result is converted',
          Then: 'the success function is called',
        ),
        procedure(() {
          final result = const Success<int, dynamic>(
            1,
          ).convert((value) => value.toString());

          expect(result, const Success<String, dynamic>('1'));
        }),
      );

      test(
        requirement(
          Given: 'a failed result',
          When: 'the result is converted',
          Then:
              'the failure function is not called and the failure is unchanged',
        ),
        procedure(() {
          final result = Failure<int, String>(
            'error',
            1,
            fakeStack,
          ).convert((value) => value.toString());

          expect(result, Failure<String, String>('error', 1, fakeStack));
        }),
      );
    });

    group('convertFailure', () {
      test(
        requirement(
          Given: 'a successful result',
          When: 'the result is converted',
          Then:
              'the failure function is not called and the success is unchanged',
        ),
        procedure(() {
          final result = const Success<int, String>(
            1,
          ).convertFailure((error) => error.toUpperCase());

          expect(result, const Success<int, String>(1));
        }),
      );

      test(
        requirement(
          Given: 'a failed result',
          When: 'the result is converted',
          Then: 'the failure function is called',
        ),
        procedure(() {
          final result = Failure<int, String>(
            'error',
            1,
            fakeStack,
          ).convertFailure((error) => error.toUpperCase());

          expect(result, Failure<int, String>('ERROR', 1, fakeStack));
        }),
      );
    });

    group('recoverWhen', () {
      test(
        requirement(
          Given: 'a failed result',
          When: 'the result is recovered with a check that matches the failure',
          Then:
              '''the result is a success with the value from the recovery function''',
        ),
        procedure(() {
          final result =
              Failure<int, String>(
                'error',
                1,
                StackTrace.fromString('stack'),
              ).recoverWhen(
                check: (error) => error == 'error',
                then: (error) => 1,
              );

          expect(result, const Success<int, String>(1));
        }),
      );

      test(
        requirement(
          Given: 'a failed result',
          When:
              '''the result is recovered with a check that does not match the failure''',
          Then: 'the result is unchanged',
        ),
        procedure(() {
          final result = Failure<int, String>('error', 1, fakeStack)
              .recoverWhen(
                check: (error) => error == 'different_error',
                then: (error) => 1,
              );

          expect(result, Failure<int, String>('error', 1, fakeStack));
        }),
      );
    });

    group('ensure', () {
      test(
        requirement(
          Given: 'a successful result',
          When: 'the result is ensured with a check that matches the success',
          Then: 'the result is unchanged',
        ),
        procedure(() {
          final result =
              const Success<int, String>(
                1,
              ).ensure(
                check: (value) => value == 1,
                otherwise: (value) => fail('Should not be called'),
              );

          expect(result, const Success<int, String>(1));
        }),
      );

      test(
        requirement(
          Given: 'a successful result',
          When:
              '''the result is ensured with a check that does not match the success''',
          Then:
              '''the result is a failure with the value from the otherwise function''',
        ),
        procedure(() {
          final result =
              const Success<int, String>(
                1,
              ).ensure(
                check: (value) => value == 2,
                otherwise: (value) => 'error',
              );

          expect(result, const Failure<int, String>('error'));
        }),
      );
    });

    group('asSuccess', () {
      test(
        requirement(
          Given: 'a successful result',
          When: 'asSuccess is called',
          Then: 'the success value is returned',
        ),
        procedure(() {
          const result = Success<int, dynamic>(1);

          expect(result.asSuccess, 1);
        }),
      );
    });

    group('asFailure', () {
      test(
        requirement(
          Given: 'a failed result',
          When: 'asFailure is called',
          Then: 'the failure value is returned',
        ),
        procedure(() {
          const result = Failure<int, String>('error');

          expect(result.asFailure, 'error');
        }),
      );
    });

    group('succeeded', () {
      test(
        requirement(
          Given: 'a successful result',
          When: 'succeeded is called',
          Then: 'returns true',
        ),
        procedure(() {
          const result = Success<int, dynamic>(1);

          expect(result.succeeded, true);
        }),
      );

      test(
        requirement(
          Given: 'a failed result',
          When: 'succeeded is called',
          Then: 'returns false',
        ),
        procedure(() {
          const result = Failure<int, String>('error');

          expect(result.succeeded, false);
        }),
      );
    });

    group('failed', () {
      test(
        requirement(
          Given: 'a successful result',
          When: 'failed is called',
          Then: 'returns false',
        ),
        procedure(() {
          const result = Success<int, dynamic>(1);

          expect(result.failed, false);
        }),
      );

      test(
        requirement(
          Given: 'a failed result',
          When: 'failed is called',
          Then: 'returns true',
        ),
        procedure(() {
          const result = Failure<int, String>('error');

          expect(result.failed, true);
        }),
      );
    });
  });

  group('Success tests', () {
    test(
      requirement(
        Given: 'a successful result',
        When: 'the value is accessed',
        Then: 'the value is returned',
      ),
      procedure(() {
        expect(const Success<int, String>(1).value, 1);
        expect(const Success<int, String>(1).val, 1);
      }),
    );
  });

  group('Failure tests', () {
    test(
      requirement(
        Given: 'a failed result',
        When: 'the value is accessed',
        Then: 'the value is returned',
      ),
      procedure(() {
        expect(const Failure<int, String>('error').value, 'error');
        expect(const Failure<int, String>('error').val, 'error');
      }),
    );
  });
}
