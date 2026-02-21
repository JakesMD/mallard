import 'package:mallard/mallard.dart';
import 'package:test/test.dart';
import 'package:test_beautifier/test_beautifier.dart';

void main() {
  group('Nothing tests', () {
    group('nothing', () {
      test(
        requirement(
          When: 'nothing is called',
          Then: 'returns an instance of Nothing',
        ),
        procedure(() {
          expect(nothing, isA<Nothing>());
        }),
      );
    });
  });
}
