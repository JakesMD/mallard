import 'package:mallard/mallard.dart';
import 'package:test/test.dart';
import 'package:test_beautifier/test_beautifier.dart';

void main() {
  final fakeStack = StackTrace.fromString('stack');

  group('Result tests', () {
    group('resolve', () {
      test(
        requirement(
          given: 'a successful result',
          whenever: 'the result is resolved',
          then: 'the success function is called',
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
          given: 'a failed result',
          whenever: 'the result is resolved',
          then: 'the failure function is called',
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
          given: 'a successful result',
          whenever: 'the result is converted',
          then: 'the success function is called',
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
          given: 'a failed result',
          whenever: 'the result is converted',
          then: 'the failure function is called',
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
          given: 'a successful result',
          whenever: 'the result is converted',
          then: 'the success function is called',
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
          given: 'a failed result',
          whenever: 'the result is converted',
          then:
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
          given: 'a successful result',
          whenever: 'the result is converted',
          then:
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
          given: 'a failed result',
          whenever: 'the result is converted',
          then: 'the failure function is called',
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
          given: 'a failed result',
          whenever:
              'the result is recovered with a check that matches the failure',
          then:
              'the result is a success with the value from the recovery '
              'function',
        ),
        procedure(() {
          final result = Failure<int, String>(
            'error',
            1,
            StackTrace.fromString('stack'),
          ).recoverWhen(check: (error) => error == 'error', then: (error) => 1);

          expect(result, const Success<int, String>(1));
        }),
      );

      test(
        requirement(
          given: 'a failed result',
          whenever:
              'the result is recovered with a check that does not match '
              'the failure',
          then: 'the result is unchanged',
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
          given: 'a successful result',
          whenever:
              'the result is ensured with a check that matches the success',
          then: 'the result is unchanged',
        ),
        procedure(() {
          final result = const Success<int, String>(1).ensure(
            check: (value) => value == 1,
            otherwise: (value) => fail('Should not be called'),
          );

          expect(result, const Success<int, String>(1));
        }),
      );

      test(
        requirement(
          given: 'a successful result',
          whenever:
              'the result is ensured with a check that does not match the '
              'success',
          then:
              'the result is a failure with the value from the otherwise '
              'function',
        ),
        procedure(() {
          final result = const Success<int, String>(
            1,
          ).ensure(check: (value) => value == 2, otherwise: (value) => 'error');

          expect(result, const Failure<int, String>('error'));
        }),
      );
    });

    group('asSuccess', () {
      test(
        requirement(
          given: 'a successful result',
          whenever: 'asSuccess is called',
          then: 'the success value is returned',
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
          given: 'a failed result',
          whenever: 'asFailure is called',
          then: 'the failure value is returned',
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
          given: 'a successful result',
          whenever: 'succeeded is called',
          then: 'returns true',
        ),
        procedure(() {
          const result = Success<int, dynamic>(1);

          expect(result.succeeded, true);
        }),
      );

      test(
        requirement(
          given: 'a failed result',
          whenever: 'succeeded is called',
          then: 'returns false',
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
          given: 'a successful result',
          whenever: 'failed is called',
          then: 'returns false',
        ),
        procedure(() {
          const result = Success<int, dynamic>(1);

          expect(result.failed, false);
        }),
      );

      test(
        requirement(
          given: 'a failed result',
          whenever: 'failed is called',
          then: 'returns true',
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
        given: 'a successful result',
        whenever: 'the value is accessed',
        then: 'the value is returned',
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
        given: 'a failed result',
        whenever: 'the value is accessed',
        then: 'the value is returned',
      ),
      procedure(() {
        expect(const Failure<int, String>('error').value, 'error');
        expect(const Failure<int, String>('error').val, 'error');
      }),
    );
  });
}
