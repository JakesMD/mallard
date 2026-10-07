import 'package:equatable/equatable.dart';

/// A value that is [Present] or [Absent].
///
/// Unlike a nullable, it tells "not provided" apart from "provided as null",
/// which is what a `copyWith` parameter needs.
sealed class Maybe<T> {
  const Maybe();

  /// Returns [Absent] for null, otherwise [Present].
  static Maybe<T> from<T>(T? value) =>
      value == null ? const Absent() : Present(value);

  /// Folds both cases into one value: [onPresent] maps a present value, and
  /// [onAbsent] stands in for a missing one.
  T2 resolve<T2>({
    required T2 Function(T value) onPresent,
    required T2 Function() onAbsent,
  }) => isPresent ? onPresent((this as Present<T>).value) : onAbsent();

  /// Maps the value with [converter], if present.
  Maybe<T2> convert<T2>(T2 Function(T value) converter) => isPresent
      ? Present(converter((this as Present<T>).value))
      : const Absent();

  /// Keeps the value only if it passes [predicate], otherwise returns
  /// [Absent].
  Maybe<T> filter(bool Function(T value) predicate) => isPresent
      ? predicate((this as Present<T>).value)
            ? this
            : const Absent()
      : this;

  /// Whether this is [Present].
  bool get isPresent => this is Present<T>;

  /// Whether this is [Absent].
  bool get isAbsent => this is Absent<T>;

  /// The value if present, otherwise null.
  T? get asNullable =>
      resolve(onPresent: (value) => value, onAbsent: () => null);
}

/// {@template mallard.present}
///
/// A [Maybe] holding a value, which may itself be null.
///
/// {@endtemplate}
final class Present<T> extends Maybe<T> with Equatable {
  /// {@macro mallard.present}
  const Present(this.value);

  /// The value.
  final T value;

  @override
  List<Object?> get props => [value];
}

/// {@template mallard.absent}
///
/// A [Maybe] without a value.
///
/// {@endtemplate}
final class Absent<T> extends Maybe<T> {
  /// {@macro mallard.absent}
  const Absent();
}

/// Returns an [Absent].
Maybe<T> absent<T>() => const Absent();

/// Returns a [Present] holding [value].
Maybe<T> present<T>(T value) => Present(value);

/// Returns [Absent] for null, otherwise [Present]. Shorthand for
/// [Maybe.from].
Maybe<T> maybe<T>(T? value) => Maybe.from(value);
