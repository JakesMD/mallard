import 'package:mallard/mallard.dart';

enum TemperatureFetchException { unknown }

Task<int, TemperatureFetchException> fetchTemperature(String city) =>
    Task.attempt(
      run: () async => '20 degrees Celsius',
      handle: (eexception) => TemperatureFetchException.unknown,
    ).convert((text) => int.parse(text.replaceAll('degrees Celsius', '')));

void main() async {
  Mallard.onTaskSuccess = (success) => print('Task succeeded with: $success');
  Mallard.onTaskFailure = (failure, exception, stack) =>
      print('Task failed with: $failure, exception: $exception stack: $stack');

  final result = await fetchTemperature('New York').run();

  final message = result.resolve(
    onSuccess: (value) => 'The temperature is $value°C',
    onFailure: (exception) => 'Failed to fetch temperature: $exception',
  );

  print(message);
}
