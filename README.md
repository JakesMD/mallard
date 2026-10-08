<p align="center">
<img src="https://github.com/JakesMD/mallard/blob/main/mallard.png?raw=true" height="200" alt="Derivative of image by PTG Dudva, CC BY-SA 3.0 via Wikimedia Commons">
</p>

<h1 align="center">Mallard</h1>

<p align="center">
  <a href="https://pub.dev/packages/mallard"><img src="https://img.shields.io/pub/v/mallard?label=pub.dev&logo=dart" alt="pub"></a>
  <a href="https://github.com/jakesmd/mallard/actions/workflows/dart_ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/jakesmd/mallard/dart_ci.yml?branch=main&label=checks&logo=github" alt="checks"></a>
  <img src="https://img.shields.io/badge/coverage-100%25-brightgreen?logo=codecov&logoColor=white" alt="codecov">
</p>

<p align="center">
  <strong>Railway Oriented Programming for Dart</strong>
  <br>
  Functional Result and Task types for type-safe error handling.
</p>

---

## Overview

Mallard treats your logic like a railway track. Instead of code "jumping" out of
flow when an error occurs (via `throw`), it switches to a failure track. Errors
become **data** you handle explicitly and type-safely.

```dart
enum WeatherError { offline, cityNotFound, badResponse }

Task<Forecast, WeatherError> fetchForecast(String city) => Task.attempt(
  run: () => weatherApi.forecast(city),
  handle: (e) => e is SocketException
      ? WeatherError.offline
      : WeatherError.badResponse,
);

final result = await fetchForecast('London').run();

final message = result.resolve(
  onSuccess: (forecast) => 'Tomorrow: ${forecast.high}°C',
  onFailure: (error) => switch (error) {
    .offline => 'You are offline.',
    .cityNotFound => 'No such city.',
    .badResponse => 'Something went wrong.',
  },
);
```

## Usage

### Results

`Result<S, F>` is either a `Success` holding an `S` or a `Failure` holding an
`F`.

**Creating a result:**

```dart
Result<double, WeatherError> parseCelsius(String raw) {
  final celsius = double.tryParse(raw);
  if (celsius == null) return const Failure(WeatherError.badResponse);
  return Success(celsius);
}
```

**Working with a result:**

```dart
final result = parseCelsius('21.5');

// Resolve both tracks into a single value
final label = result.resolve(
  onSuccess: (celsius) => '$celsius°C',
  onFailure: (error) => 'Unavailable: ${error.name}',
);

final newResult = result

  // Fail if the check returns false
  .ensure(
    check: (celsius) => celsius > -90,
    otherwise: (celsius) => WeatherError.badResponse,
  )

  // Recover from specific failures
  .recoverWhen(
    check: (error) => error == WeatherError.offline,
    then: (error) => lastKnownCelsius,
  )

  // Transform the success value
  .convert((celsius) => celsius * 9 / 5 + 32)

  // Transform the failure value
  .convertFailure((error) => 'Weather error: ${error.name}')

  // Transform both at once
  .convertBoth(
    onSuccess: (fahrenheit) => '$fahrenheit°F',
    onFailure: (message) => message.toUpperCase(),
  );

// Check the track
if (result.succeeded) print(result.asSuccess);
if (result.failed) print(result.asFailure);

// A failure caught from a throw keeps its exception and stack trace,
// through every operator
if (result case Failure(:final exception, :final stackTrace)) {
  logger.error('Parsing failed', exception, stackTrace);
}
```

### Tasks

`Task<S, F>` wraps an operation that produces a `Result`. Nothing runs until
`run()`, and every `run()` runs it again.

**Creating a task:**

```dart
// Task.attempt: catches exceptions and turns them into failures
Task<Forecast, WeatherError> fetchForecast(String city) => Task.attempt(
  run: () => weatherApi.forecast(city),
  handle: (e) => e is SocketException
      ? WeatherError.offline
      : WeatherError.badResponse,
);

// Task(): return the Result yourself. Nothing is caught.
Task<String, WeatherError> savedCity = Task(() async {
  final city = await storage.read('city');
  if (city == null) return const Failure(WeatherError.cityNotFound);
  return Success(city);
});
```

**Working with a task:**

```dart
// Run the task and get a Result
final result = await savedCity.run();

final newTask = savedCity

  // Run another task if this one succeeds
  .chain((city) => fetchForecast(city))

  // Run a function that returns a Result if this one succeeds
  .then((forecast) async => validateForecast(forecast))

  // Run a function that may throw if this one succeeds, catching it as a failure
  .thenAttempt(
    run: (forecast) async {
      await cache.write(forecast);
      return forecast;
    },
    handle: (e) => WeatherError.badResponse,
  )

  // Fail if the check returns false
  .ensure(
    check: (forecast) => forecast.days.isNotEmpty,
    otherwise: (forecast) => WeatherError.badResponse,
  )

  // Recover from specific failures
  .recoverWhen(
    check: (error) => error == WeatherError.offline,
    then: (error) => cachedForecast,
  )

  // Transform the success value
  .convert((forecast) => forecast.high)

  // Transform the failure value
  .convertFailure((error) => 'Weather error: ${error.name}')

  // Transform both at once
  .convertBoth(
    onSuccess: (high) => 'Tomorrow: $high°C',
    onFailure: (message) => message.toUpperCase(),
  )

  // Transform the whole Result
  .apply((result) => result.recoverWhen(
    check: (message) => message.contains('OFFLINE'),
    then: (message) => 'Showing cached weather',
  ));
```

### ResultStreams

`ResultStream<S, F>` is the sibling of `Task` that emits many results. `run()`
returns a `Stream<Result<S, F>>`.

**Creating a result stream:**

```dart
// ResultStream.attempt: wraps a plain stream, turning its errors into failures
ResultStream<double, WeatherError> watchTemperature(String city) =>
    ResultStream.attempt(
      run: () => weatherSocket.temperatures(city),
      handle: (e) => WeatherError.offline,
    );

// ResultStream.fromTask: emits the task's result, then closes
ResultStream<Forecast, WeatherError> forecast = ResultStream.fromTask(
  fetchForecast('London'),
);

// ResultStream(): your source already emits Results
ResultStream<double, WeatherError> readings = ResultStream(() async* {
  yield const Success(21.5);
  yield const Failure(WeatherError.offline); // Failures don't end the stream
  yield const Success(22.0);
  // A throw here would end the stream with an untyped error, so yield a
  // Failure instead
});
```

**Running a result stream:**

```dart
// Each run() calls the factory again, so it must return a fresh or broadcast
// stream
watchTemperature('London').run().listen((result) {
  print(result.resolve(
    onSuccess: (celsius) => '$celsius°C',
    onFailure: (error) => 'Lost signal: ${error.name}',
  ));
});
```

**Working with a result stream:**

Every `Task` operator works here too, applied to each result as it arrives.

```dart
final newStream = watchTemperature('London')

  // Transform each success value
  .convert((celsius) => celsius * 9 / 5 + 32)

  // A failure made here is data too and doesn't end the stream
  .ensure(
    check: (fahrenheit) => fahrenheit < 150,
    otherwise: (fahrenheit) => WeatherError.badResponse,
  )

  // Async steps run one at a time and in order, pausing the source, like
  // asyncMap. Failures skip the step but keep their place.
  .thenAttempt(
    run: (fahrenheit) async {
      await database.insertReading(fahrenheit);
      return fahrenheit;
    },
    handle: (e) => WeatherError.badResponse,
  )

  // Apply any StreamTransformer, e.g. distinct, take or debounce
  .transform(StreamTransformer.fromBind((results) => results.distinct()))

  // Stop at the first failure: emit it, then close and cancel the source
  .untilFailure();

// If a callback you pass throws, that event becomes an untyped stream error
// and later events keep flowing
```

**Switching streams:**

```dart
// chainStream only listens to the stream for the latest value
ResultStream<double, WeatherError> temperature = watchSelectedCity()
  .chainStream((city) => watchTemperature(city));

// selected city: 'Paris'  → listens to Paris
// selected city: 'Oslo'   → cancels Paris, listens to Oslo
// selected city: Failure  → cancels Oslo, emits the failure

// thenAttemptStream does the same with a plain stream
ResultStream<double, WeatherError> temperature = watchSelectedCity()
  .thenAttemptStream(
    run: (city) => weatherSocket.temperatures(city),
    handle: (e) => WeatherError.offline,
  );

// Tasks can start a stream too. If the task fails, its failure is emitted and
// the stream closes.
ResultStream<double, WeatherError> temperature = savedCity
  .chainStream((city) => watchTemperature(city));
```

**Combining streams:**

```dart
// combineWith combines the latest success of each stream
ResultStream<Conditions, WeatherError> conditions = watchTemperature(city)
  .combineWith(watchHumidity(city), combine: Conditions.new);

// temperature 21       → nothing yet, humidity hasn't emitted
// humidity 60          → Conditions(21, 60)
// temperature 22       → Conditions(22, 60)
// temperature Failure  → Failure
// humidity 65          → nothing, temperature's latest is a failure
// temperature 23       → Conditions(23, 65)

// combineWithTwo to combineWithFive take a record of other streams
ResultStream<Dashboard, WeatherError> dashboard = watchTemperature(city)
  .combineWithTwo(
    (watchHumidity(city), watchWind(city)),
    combine: (celsius, humidity, wind) => Dashboard(celsius, humidity, wind),
  );

// Combine inside chainStream to rebuild every stream when the city changes
ResultStream<Dashboard, WeatherError> dashboard = watchSelectedCity()
  .chainStream((city) => watchTemperature(city).combineWithTwo(
    (watchHumidity(city), watchWind(city)),
    combine: Dashboard.new,
  ));
```

**Restarting a stream:**

```dart
ResultStream<double, WeatherError> temperature = watchTemperature(city)
  .restartWhen(

    // Asked on each failure. attempt counts the restarts since the last success.
    // true restarts, false emits the failure.
    onFailure: (error, attempt) => attempt < 5,

    // Asked when the source closes
    onClose: (attempt) => true,

    // The wait before each restart. Leave it out to restart straight away.
    delay: (attempt) => Duration(seconds: 1 << attempt), // Back off

    // The default: drop the failure on a restart. Pass false to emit it first.
    hideFailure: true,
  );

// Restart each source rather than the combined stream, which would restart
// them all
final conditions = watchTemperature(city)
  .restartWhen(onClose: (attempt) => true)
  .combineWith(
    watchHumidity(city).restartWhen(onClose: (attempt) => true),
    combine: Conditions.new,
  );
```

### Maybe

`Maybe` tells "not provided" apart from "provided as null", which is exactly
what `copyWith` needs.

```dart
class Settings {
  const Settings({this.city});

  final String? city;

  Settings copyWith({Maybe<String?> city = const Absent()}) => Settings(
    city: city.resolve(onPresent: (city) => city, onAbsent: () => this.city),
  );
}

settings.copyWith();                      // Keeps the city
settings.copyWith(city: present('Oslo')); // Sets it
settings.copyWith(city: present(null));   // Clears it
```

**Working with a maybe:**

```dart
final units = maybe(queryParameters['units']); // null → Absent

final newMaybe = units

  // Transform the value if present
  .convert((units) => units.toLowerCase())

  // Keep the value only if the check passes, otherwise Absent
  .filter((units) => units == 'metric' || units == 'imperial');

// Handle both cases
final label = units.resolve(
  onPresent: (units) => units,
  onAbsent: () => 'metric',
);

if (units.isPresent) print('Units chosen');
if (units.isAbsent) print('Using the default');

final nullable = units.asNullable;
```

### Nothing

`Nothing` is the success value of an operation that doesn't return anything.

```dart
Task<Nothing, WeatherError> saveCity(String city) => Task.attempt(
  run: () async {
    await storage.write('city', city);
    return nothing;
  },
  handle: (e) => WeatherError.badResponse,
);
```

---

## Advanced

### Global Callbacks

Observe every task and result stream in one place, e.g. for logging or
analytics:

```dart
Mallard.onTaskSuccess = (value) {
  analytics.track('task_success');
};

Mallard.onTaskFailure = (failure, exception, stackTrace) {
  logger.error('Task failed: $failure', exception, stackTrace);
};

// Same signatures, fired for each result a ResultStream emits
Mallard.onStreamSuccess = (value) {};
Mallard.onStreamFailure = (failure, exception, stackTrace) {};

// Fired on each restartWhen restart, with nulls on close
Mallard.onStreamRestart = (failure, exception, stackTrace, attempt) {
  logger.warning('Stream restarted (attempt $attempt): $failure');
};
```

Only the outermost run fires callbacks, apart from `onStreamRestart`:

```dart
final shoutedCity = Task(() async {
  final city = await savedCity.run(); // Inner run: no callback
  return city.convert((city) => city.toUpperCase());
});

await shoutedCity.run(); // Fires onTaskSuccess once

// The same goes for operators: chain, chainStream, combineWith and the rest
// fire callbacks once per result of the outer run
await savedCity.chain(fetchForecast).run(); // Fires onTaskSuccess once
```

### Custom Aliases

Create your own names with extension types. Mallard ships `short.dart` as an
example:

```dart
import 'package:mallard/short.dart';

// Type aliases
final ok = Res<double, WeatherError>.ok(21.5);
final err = Res<double, WeatherError>.err(WeatherError.offline);

// Parameter aliases
final label = ok.resolve(
  onOk: (celsius) => '$celsius°C',
  onErr: (error) => 'Unavailable: ${error.name}',
);

// Property aliases
if (ok.isOk) print(ok.asOk);
if (err.isErr) print(err.asErr);

// ResStream is the short ResultStream
final temperature = ResStream<double, WeatherError>.fromResults([ok])
  .convertErr((error) => error.name)   // convertFailure
  .restartWhen(onErr: (error, attempt) => attempt < 3) // onFailure
  .untilErr();                         // untilFailure
```

---

## Testing

Use `Task.succeed` and `Task.fail` to stub tasks:

```dart
test('shows tomorrow\'s high', () async {
  when(() => weatherApi.fetchForecast(any()))
    .thenReturn(Task.succeed(Forecast(high: 21)));

  final result = await repository.fetchForecast('London').run();

  expect(result.asSuccess.high, 21);
});

test('reports when offline', () async {
  when(() => weatherApi.fetchForecast(any()))
    .thenReturn(Task.fail(WeatherError.offline));

  final result = await repository.fetchForecast('London').run();

  expect(result.asFailure, WeatherError.offline);
});
```

`ResultStream.succeed`, `ResultStream.fail` and `ResultStream.fromResults` do
the same for streams:

```dart
test('passes readings and failures through', () {
  when(() => weatherApi.watchTemperature(any())).thenReturn(
    ResultStream.fromResults([
      const Success(20.0),
      const Failure(WeatherError.offline),
    ]),
  );

  expect(
    repository.watchTemperature('London').run(),
    emitsInOrder([
      const Success<double, WeatherError>(20.0),
      const Failure<double, WeatherError>(WeatherError.offline),
    ]),
  );
});
```
