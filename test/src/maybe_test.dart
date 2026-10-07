import 'package:mallard/mallard.dart';
import 'package:test/test.dart';
import 'package:test_beautifier/test_beautifier.dart';

void main() {
  group('Maybe tests', () {
    group('Maybe.from', () {
      test(
        requirement(
          given: 'a non-null value',
          whenever: 'Maybe.from is called',
          then: 'returns a present maybe containing the value',
        ),
        procedure(() {
          final result = Maybe.from(1);

          expect(result, present(1));
        }),
      );

      test(
        requirement(
          given: 'a null value',
          whenever: 'Maybe.from is called',
          then: 'returns an absent maybe',
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
          given: 'a present value',
          whenever: 'the maybe is resolved',
          then: 'the [onPresent] function is called',
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
          given: 'an absent value',
          whenever: 'the maybe is resolved',
          then: 'the [onAbsent] function is called',
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
          given: 'a present value',
          whenever: 'the maybe is converted',
          then: 'returns a new maybe with the new value',
        ),
        procedure(() {
          final result = present(1).convert((value) => value + 1);

          expect(result, present(2));
        }),
      );

      test(
        requirement(
          given: 'an absent value',
          whenever: 'the maybe is converted',
          then: 'returns an absent maybe',
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
          given: 'a present value that satisfies the predicate',
          whenever: 'the maybe is filtered',
          then: 'returns the original maybe',
        ),
        procedure(() {
          final result = present(1).filter((value) => value > 0);

          expect(result, present(1));
        }),
      );

      test(
        requirement(
          given: 'a present value that does not satisfy the predicate',
          whenever: 'the maybe is filtered',
          then: 'returns an absent maybe',
        ),
        procedure(() {
          final result = present(1).filter((value) => value < 0);

          expect(result, absent<int>());
        }),
      );

      test(
        requirement(
          given: 'an absent value',
          whenever: 'the maybe is filtered',
          then: 'returns an absent maybe',
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
          given: 'a present value',
          whenever: 'isPresent is called',
          then: 'returns true',
        ),
        procedure(() {
          expect(present(1).isPresent, isTrue);
        }),
      );

      test(
        requirement(
          given: 'an absent value',
          whenever: 'isPresent is called',
          then: 'returns false',
        ),
        procedure(() {
          expect(absent<String>().isPresent, isFalse);
        }),
      );
    });

    group('isAbsent', () {
      test(
        requirement(
          given: 'a present value',
          whenever: 'isAbsent is called',
          then: 'returns false',
        ),
        procedure(() {
          expect(present(1).isAbsent, isFalse);
        }),
      );

      test(
        requirement(
          given: 'an absent value',
          whenever: 'isAbsent is called',
          then: 'returns true',
        ),
        procedure(() {
          expect(absent<String>().isAbsent, isTrue);
        }),
      );
    });

    group('asNullable', () {
      test(
        requirement(
          given: 'a present value',
          whenever: 'asNullable is called',
          then: 'returns the value',
        ),
        procedure(() {
          expect(present(1).asNullable, 1);
        }),
      );

      test(
        requirement(
          given: 'an absent value',
          whenever: 'asNullable is called',
          then: 'returns null',
        ),
        procedure(() {
          expect(absent<String>().asNullable, isNull);
        }),
      );
    });

    group('present', () {
      test(
        requirement(
          given: 'a present value',
          whenever: 'a present is created',
          then: 'returns a [Present] instance with the value',
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
          whenever: 'an absent is created',
          then: 'returns a [Absent] instance',
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
          given: 'a non-null value',
          whenever: 'maybe is called',
          then: 'returns a present maybe',
        ),
        procedure(() {
          final result = maybe(1);

          expect(result, present(1));
        }),
      );

      test(
        requirement(
          given: 'a null value',
          whenever: 'maybe is called',
          then: 'returns an absent maybe',
        ),
        procedure(() {
          final result = maybe(null);

          expect(result, absent<dynamic>());
        }),
      );
    });
  });
}
