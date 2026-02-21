<h1 align="center">Mallard Bloc</h1>

<p align="center">
  <a href="https://pub.dev/packages/mallard"><img src="https://img.shields.io/pub/v/mallard?label=pub.dev&logo=dart" alt="pub"></a>
  <a href="https://github.com/jakesmd/mallard/actions/workflows/dart_ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/jakesmd/mallard/dart_ci.yml?branch=main&label=checks&logo=github" alt="checks"></a>
  <img src="https://img.shields.io/badge/coverage-0%25-red?logo=codecov&logoColor=white" alt="codecov">
</p>

<p align="center">
  Take advantage of <a href="https://pub.dev/packages/mallard">Mallard</a>'s railway oriented programming to radically simplify bloc applications.
</p>

> [!EXPERIMENTAL]
> This is not yet production ready. But feel free to play around and suggest
> improvements.

---

## Usage

```dart
// Define a your cubit state as a typedef.
typedef RandomNumberFetchState = TaskBlocState<int, RandomNumberFetchException>;

// Create your cubit with the TaskCubitMixin.
class RandomNumberFetchCubit extends Cubit<RandomNumberFetchState>
    with TaskCubitMixin {
  RandomNumberFetchCubit(this.randomRepository) : super(.initial());

  final RandomRepository randomRepository;

  // Make a request call and pass in your job. Everything else is handled for you.
  Future<void> fetchRandomNumber() =>
      request(randomRepository.fetchRandomNumber());
}

// ...

// Update your UI based on the current request state.
BlocBuilder<RandomNumberFetchCubit, RandomNumberFetchState>(
    builder: (context, state) => switch (state.status) {
        .initial => const Text('Generate a random number!'),
        .inProgress => const CircularProgressIndicator(),
        .succeeded => Text('${state.success}'),
        .failed => Text(
          switch (state.failure!) {
            .unknown => 'Unknown error occurred.',
            .overflow => 'Error: Overflowed',
          },
        ),
    },
),
```

### For more flexibility

```dart
// Extend TaskBlocState instead of using typedef.
class RandomNumberFetchState
    extends TaskBlocState<int, RandomNumberFetchException> {
  RandomNumberFetchState.initial() : super.initial();

  RandomNumberFetchState.inProgress() : super.inProgress();

  RandomNumberFetchState.completed(super.result) : super.completed();
}

class RandomNumberFetchCubit extends Cubit<RandomNumberFetchState> {
  RandomNumberFetchCubit(this.randomRepository) : super(.initial());

  final RandomRepository randomRepository;

  // Emit the state changes manually.
  Future<void> fetchRandomNumber() async {
    if (state.isInProgress) return;

    emit(.inProgress());

    final result = await randomRepository.fetchRandomNumber().run();

    emit(.completed(result));
  }
}
```
