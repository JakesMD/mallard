import 'package:mallard/mallard.dart';
import 'package:test/test.dart';
import 'package:test_beautifier/test_beautifier.dart';

void main() {
  group('Maybe tests', () {
    group('Maybe.from', () {
      test(
        requirement(
          Given: 'a non-null value',
          When: 'Maybe.from is called',
          Then: 'returns a present maybe containing the value',
        ),
        procedure(() {
          final result = Maybe.from(1);

          expect(result, present(1));
        }),
      );

      test(
        requirement(
          Given: 'a null value',
          When: 'Maybe.from is called',
          Then: 'returns an absent maybe',
        ),
        procedure(() {
          final result = Maybe.from(null);

          expect(result, absent<dynamic>());
        }),
      );
    });

    group('resolve', () {
      test(
        requirement(
          Given: 'a present value',
          When: 'the maybe is resolved',
          Then: 'the [onPresent] function is called',
        ),
        procedure(() {
          final result = present(1).resolve(
            onAbsent: () => fail('Should not be called'),
            onPresent: (value) => value,
          );

          expect(result, 1);
        }),
      );

      test(
        requirement(
          Given: 'an absent value',
          When: 'the maybe is resolved',
          Then: 'the [onAbsent] function is called',
        ),
        procedure(() {
          final result = absent<String>().resolve(
            onAbsent: () => 'absent',
            onPresent: (_) => fail('Should not be called'),
          );

          expect(result, 'absent');
        }),
      );
    });

    group('convert', () {
      test(
        requirement(
          Given: 'a present value',
          When: 'the maybe is converted',
          Then: 'returns a new maybe with the new value',
        ),
        procedure(() {
          final result = present(1).convert((value) => value + 1);

          expect(result, present(2));
        }),
      );

      test(
        requirement(
          Given: 'an absent value',
          When: 'the maybe is converted',
          Then: 'returns an absent maybe',
        ),
        procedure(() {
          final result = absent<int>().convert((value) => value + 1);

          expect(result, absent<int>());
        }),
      );
    });

    group('filter', () {
      test(
        requirement(
          Given: 'a present value that satisfies the predicate',
          When: 'the maybe is filtered',
          Then: 'returns the original maybe',
        ),
        procedure(() {
          final result = present(1).filter((value) => value > 0);

          expect(result, present(1));
        }),
      );

      test(
        requirement(
          Given: 'a present value that does not satisfy the predicate',
          When: 'the maybe is filtered',
          Then: 'returns an absent maybe',
        ),
        procedure(() {
          final result = present(1).filter((value) => value < 0);

          expect(result, absent<int>());
        }),
      );

      test(
        requirement(
          Given: 'an absent value',
          When: 'the maybe is filtered',
          Then: 'returns an absent maybe',
        ),
        procedure(() {
          final result = absent<int>().filter((value) => value > 0);

          expect(result, absent<int>());
        }),
      );
    });

    group('isPresent', () {
      test(
        requirement(
          Given: 'a present value',
          When: 'isPresent is called',
          Then: 'returns true',
        ),
        procedure(() {
          expect(present(1).isPresent, isTrue);
        }),
      );

      test(
        requirement(
          Given: 'an absent value',
          When: 'isPresent is called',
          Then: 'returns false',
        ),
        procedure(() {
          expect(absent<String>().isPresent, isFalse);
        }),
      );
    });

    group('isAbsent', () {
      test(
        requirement(
          Given: 'a present value',
          When: 'isAbsent is called',
          Then: 'returns false',
        ),
        procedure(() {
          expect(present(1).isAbsent, isFalse);
        }),
      );

      test(
        requirement(
          Given: 'an absent value',
          When: 'isAbsent is called',
          Then: 'returns true',
        ),
        procedure(() {
          expect(absent<String>().isAbsent, isTrue);
        }),
      );
    });

    group('asNullable', () {
      test(
        requirement(
          Given: 'a present value',
          When: 'asNullable is called',
          Then: 'returns the value',
        ),
        procedure(() {
          expect(present(1).asNullable, 1);
        }),
      );

      test(
        requirement(
          Given: 'an absent value',
          When: 'asNullable is called',
          Then: 'returns null',
        ),
        procedure(() {
          expect(absent<String>().asNullable, isNull);
        }),
      );
    });

    group('present', () {
      test(
        requirement(
          Given: 'a present value',
          When: 'a present is created',
          Then: 'returns a [Present] instance with the value',
        ),
        procedure(() {
          final p = present(1);

          expect(p, const Present(1));
          expect((p as Present).value, 1);
        }),
      );
    });

    group('absent', () {
      test(
        requirement(
          When: 'an absent is created',
          Then: 'returns a [Absent] instance',
        ),
        procedure(() {
          final a = absent<int>();

          expect(a, isA<Absent<int>>());
        }),
      );
    });

    group('maybe', () {
      test(
        requirement(
          Given: 'a non-null value',
          When: 'maybe is called',
          Then: 'returns a present maybe',
        ),
        procedure(() {
          final result = maybe(1);

          expect(result, present(1));
        }),
      );

      test(
        requirement(
          Given: 'a null value',
          When: 'maybe is called',
          Then: 'returns an absent maybe',
        ),
        procedure(() {
          final result = maybe(null);

          expect(result, absent<dynamic>());
        }),
      );
    });
  });
}
