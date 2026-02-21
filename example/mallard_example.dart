import 'dart:convert';
import 'dart:io';

import 'package:mallard/mallard.dart';

enum SettingsLoadException { notFound, invalidJson, permissionDenied }

class Settings {
  Settings.fromJson(Map<String, dynamic> json) : name = json['name'] as String;

  final String name;
}

Task<Settings, SettingsLoadException> loadSettings() =>
    Task.attempt(
          run: () => File('settings.json').readAsString(),
          handle: (exception) => exception is PathNotFoundException
              ? SettingsLoadException.notFound
              : SettingsLoadException.permissionDenied,
        )
        .thenAttempt(
          run: (jsonString) => jsonDecode(jsonString) as Map<String, dynamic>,
          handle: (_) => SettingsLoadException.invalidJson,
        )
        .ensure(
          check: (json) => json.containsKey('name') && json['name'] is String,
          otherwise: (_) => SettingsLoadException.invalidJson,
        )
        .convert(Settings.fromJson);

void main() async {
  Mallard.onTaskFailure = (failure, exception, stackTrace) =>
      print('[Mallard callback] Task failed with exception: $exception');

  final result = await loadSettings().run();

  final message = result.resolve(
    onSuccess: (settings) => 'Settings loaded: ${settings.name}',
    onFailure: (error) => switch (error) {
      .notFound => 'Settings file not found.',
      .invalidJson => 'Settings file is corrupted.',
      .permissionDenied => 'Check your app storage permissions.',
    },
  );

  print('\nmessage: $message');
}
