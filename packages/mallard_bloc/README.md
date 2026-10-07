<h1 align="center">Mallard Bloc</h1>

<p align="center">
  <a href="https://pub.dev/packages/mallard"><img src="https://img.shields.io/pub/v/mallard?label=pub.dev&logo=dart" alt="pub"></a>
  <a href="https://github.com/jakesmd/mallard/actions/workflows/dart_ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/jakesmd/mallard/dart_ci.yml?branch=main&label=checks&logo=github" alt="checks"></a>
  <img src="https://img.shields.io/badge/coverage-0%25-red?logo=codecov&logoColor=white" alt="codecov">
</p>

<p align="center">
  Cubits driven by <a href="https://pub.dev/packages/mallard">Mallard</a> tasks and result streams, with no loading or error state to wire by hand.
</p>

> [!WARNING]
> Experimental: not yet production ready. Feel free to try it and suggest
> improvements.

---

## Overview

| Piece                    | What it does                                                         |
| ------------------------ | -------------------------------------------------------------------- |
| `TaskBlocState<S, F>`    | A `status` (initial, in progress, succeeded, failed) and the latest `Result`. |
| `TaskCubitMixin`         | Runs one `Task` at a time with `request`.                            |
| `ResultStreamCubitMixin` | Follows a live `ResultStream` with `subscribe` and `unsubscribe`.    |

Use one mixin per cubit.

## Running a task

```dart
typedef ForecastState = TaskBlocState<Forecast, WeatherError>;

class ForecastCubit extends Cubit<ForecastState>
    with TaskCubitMixin<Forecast, WeatherError> {
  ForecastCubit(this.repository) : super(.initial());

  final WeatherRepository repository;

  Future<void> fetch(String city) => request(repository.fetchForecast(city));
}
```

`request` emits in progress, then a completed state for the result. It does
nothing while a request is already in progress. If the task throws, the error
goes to `addError` and the state from before the request comes back.

Build the UI from the status:

```dart
BlocBuilder<ForecastCubit, ForecastState>(
  builder: (context, state) => switch (state.status) {
    .initial => const Text('Pick a city.'),
    .inProgress => const CircularProgressIndicator(),
    .succeeded => Text('Tomorrow: ${state.success!.high}°C'),
    .failed => Text(switch (state.failure!) {
      .offline => 'You are offline.',
      .cityNotFound => 'No such city.',
      .badResponse => 'The weather service misbehaved.',
    }),
  },
),
```

## Following a stream

```dart
typedef TemperatureState = TaskBlocState<double, WeatherError>;

class TemperatureCubit extends Cubit<TemperatureState>
    with ResultStreamCubitMixin<double, WeatherError> {
  TemperatureCubit(this.repository) : super(.initial());

  final WeatherRepository repository;

  // Calling this again switches to the new city's stream.
  void watch(String city) => subscribe(repository.watchTemperature(city));

  Future<void> stopWatching() => unsubscribe();
}
```

- Each result emits a completed state. The state is in progress, keeping the
  previous result, until the first one arrives.
- If the stream closes, errors or is unsubscribed before its first result, the
  state from before `subscribe` comes back. After that, the last state stays.
- Untyped stream errors go to `addError`, and the subscription stays live.
- Closing the cubit cancels the subscription.

## Without the mixins

Extend `TaskBlocState` instead of using a typedef, and emit the states
yourself:

```dart
class ForecastState extends TaskBlocState<Forecast, WeatherError> {
  ForecastState.initial() : super.initial();

  ForecastState.inProgress() : super.inProgress();

  ForecastState.completed(super.result) : super.completed();
}

class ForecastCubit extends Cubit<ForecastState> {
  ForecastCubit(this.repository) : super(.initial());

  final WeatherRepository repository;

  Future<void> fetch(String city) async {
    if (state.isInProgress) return;

    emit(.inProgress());
    emit(.completed(await repository.fetchForecast(city).run()));
  }
}
```
