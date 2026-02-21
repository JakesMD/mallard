import 'dart:math';

import 'package:mallard/mallard.dart';

enum RandomNumberFetchException { unknown, overflow }

class RandomRepository {
  Task<int, RandomNumberFetchException> fetchRandomNumber() =>
      Task.attempt(
        run: () {
          return Future<int>.delayed(
            const Duration(seconds: 1),
            () => Random().nextInt(20),
          );
        },
        handle: (_) => RandomNumberFetchException.unknown,
      ).ensure(
        check: (value) => value < 10,
        otherwise: (_) => RandomNumberFetchException.overflow,
      );
}
