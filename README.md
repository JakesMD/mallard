<p align="center">
<img src="https://github.com/JakesMD/mallard/blob/main/mallard.png?raw=true" height="200" alt="Derivative of image by PTG Dudva, CC BY-SA 3.0 via Wikimedia Commons">
</p>

<h1 align="center">Mallard</h1>

<p align="center">
  <a href="https://pub.dev/packages/mallard"><img src="https://img.shields.io/pub/v/mallard?label=pub.dev&logo=dart" alt="pub"></a>
  <a href="https://github.com/jakesmd/mallard/actions/workflows/dart_ci.yml"><img src="https://img.shields.io/github/actions/workflow/status/jakesmd/mallard/dart_ci.yml?branch=main&label=tests&logo=github" alt="tests"></a>
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

## Usage

### Results

`Result<S, F>` represents either success or failure. Instead of throwing
exceptions, operations return a `Result` so errors become data you handle
explicitly and type-safely.

**Creating a result:**

```dart
Result<Map, ParseError> result = Success({'version': '1.0.0'});
Result<Map, ParseError> result = Failure(ParseError.invalidJson);
```

**Working with a result:**

```dart
// Get a single value from success or failure
final message = result.resolve(
  onSuccess: (settings) => 'Loaded version ${settings['version']}',
  onFailure: (error) => 'Error: ${error.name}',
);

final newResult = result

  // Transform success value to a different type
  .convert((settings) => settings['version'])

  // Transform the failure value
  .convertFailure((error) => 'Parse Error: ${error.name}')

  // Transform both success and failure types
  .convertBoth(
    onSuccess: (settings) => 'Settings ${settings.length} fields',
    onFailure: (error) => 'Failed: ${error.name}',
  )

  // Validate success value, fail if check returns false
  .ensure(
    check: (settings) => settings.containsKey('version'),
    otherwise: (settings) => ParseError.missingField,  // Create failure from success value
  )

  // Recover from specific failures
  .recoverWhen(
    check: (error) => error == ParseError.notFound,
    then: (error) => {'version': '1.0.0'},  // Return success value
  );

// Check the state
if (result.succeeded) print('Success: ${result.asSuccess}');
if (result.failed) print('Error: ${result.asFailure}');
```

### Tasks

`Task` wraps synchronous and asynchronous operations and returns a `Result`.
Exceptions are automatically captured as failures, letting you chain operations
and handle outcomes type-safely.

**Creating a task:**

```dart
// Task.attempt — Most common: automatically catches exceptions and converts them to failures
Task<Map, ParseError> task = Task.attempt(
  run: () async => jsonDecode(await File('settings.json').readAsString()) as Map,
  handle: (e) => e is FileSystemException
      ? ParseError.notFound
      : ParseError.invalidJson,
);

// Task() — For fine-grained control: you handle try-catch and return a Result
Task<Map, ParseError> task = Task(() async {
  try {
    final content = await File('settings.json').readAsString();
    return Success(jsonDecode(content) as Map);
  } on FileSystemException {
    return Failure(ParseError.notFound);
  } catch (e) {
    return Failure(ParseError.invalidJson);
  }
});
```

**Working with a task:**

```dart
// Execute the task and get a Result
final result = await task.run();

final newTask = task

  // Transform success value to a different type
  .convert((settings) => settings['version'])

  // Transform the failure value
  .convertFailure((error) => 'Parse Error: ${error.name}')

  // Transform both success and failure types
  .convertBoth(
    onSuccess: (settings) => 'Settings ${settings.length} fields',
    onFailure: (error) => 'Failed: ${error.name}',
  )

  // Validate success value, fail if check returns false
  .ensure(
    check: (settings) => settings.containsKey('version'),
    otherwise: (settings) => ParseError.missingField,  // Create failure from success value
  )

  // Recover from specific failures
  .recoverWhen(
    check: (error) => error == ParseError.notFound,
    then: (error) => {'version': '1.0.0'},  // Return success value
  )

  // Chain another task if this task succeeds
  .then((settings) async {
    try {
      final validated = await validateSettings(settings);
      return Success(validated);
    } catch (e) {
      return Failure(ParseError.invalidJson);
    }
  })

  // Chain another async function, capturing exceptions as failures
  .thenAttempt(
    run: (settings) async => await saveSettings(settings),
    handle: (e) => ParseError.invalidJson,
  )

  // Chain another task if this task succeeds
  .chain((settings) => loadUserPreferences(settings['userId']))

  // Apply a function to transform the result
  .apply((result) => result.convert((s) => s.toString()));
```

### Maybe

`Maybe` represents a value that may or may not have been provided. Use
`Present<T>` for provided values and `Absent` for absent values. This is useful
in functions like `copyWith` where you need to distinguish between "not
provided" and "explicitly null".

**Creating a maybe:**

```dart
const a = maybe(settings['theme']);
const b = absent();
const c = maybe(null);  // → Absent
```

**Working with a maybe:**

```dart
const maybe = maybe(userTheme);

// Handle both cases
final theme = maybe.resolve(
  onPresent: (value) => value,
  onAbsent: () => 'light',
);

final newMaybe = maybe

  // Transform the value if present
  .convert((theme) => theme.toUpperCase())

  // Keep the value only if condition is true, otherwise Absent
  .filter((theme) => theme == 'light' || theme == 'dark');

// Check if present
if (maybe.isPresent) print('Theme is set');

// Check if absent
if (maybe.isAbsent) print('Theme uses default');

// Get as nullable
final theme = maybe.asNullable;
```

### Nothing

`Nothing` represents a void return type. Use it for operations that perform an
action without returning a value, like writing to a file or logging.

```dart
Task<Nothing, ParseError> saveSettings(Map settings) =>
    Task.attempt(
      run: () => File('settings.json').writeAsString(jsonEncode(settings)),
      handle: (_) => ParseError.invalidJson,
    );

final result = await saveSettings({'version': '1.0.0'}).run();
result.resolve(
  onSuccess: (_) => print('Settings saved'),
  onFailure: (error) => print('Save failed: ${error.name}'),
);
```

---

## Advanced

### Global Callbacks

Set up app-wide handlers to observe all task execution. Useful for logging,
analytics, debugging, and monitoring:

```dart
Mallard.onTaskSuccess = (value) {
  analytics.track('task_success', value);
};

Mallard.onTaskFailure = (failure, exception, stackTrace) {
  logger.error('Task failed', exception, stackTrace);
};
```

### Custom Aliases

Create your own type aliases to match your naming conventions using extension
types.

Mallard provides `short.dart` as an example:

```dart
import 'package:mallard/short.dart';

// Type aliases
final ok = Res<Map, ParseError>.ok({'version': '1.0.0'});
final err = Res<Map, ParseError>.err(ParseError.invalidJson);

// Parameter aliases
result.resolve(
  onOk: (settings) => 'Loaded ${settings.length} settings',
  onErr: (error) => 'Error: ${error.name}',
);

// Property aliases
if (result.isOk) print(result.ok);
```

You can create your own extension types to customize type names, method names,
and parameter names.

---

## Testing

Use `Task.succeed` and `Task.fail` to mock task results in your tests.

```dart
// Create a task that immediately succeeds (useful for testing)
test('Example', () {
  when(() => weatherClient.fetch(any()))
    .thenReturn(Task.succeed(Temperature(celsius: 20)));

  final result = await weatherRepository.fetch('London').run();

  expect(result.asSuccess.celsius, 20);
});

// Create a task that immediately fails (useful for testing)
test('Example', () {
  when(() => weatherClient.fetch(any()))
    .thenReturn(Task.fail(WeatherError.notFound));

  final result = await weatherRepository.fetch('London').run();

  expect(result.asFailure, WeatherError.notFound);
});
```
