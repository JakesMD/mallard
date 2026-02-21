import 'package:equatable/equatable.dart';

/// {@template mallard.maybe}
///
/// Represents a value that may be present or absent.
///
/// {@endtemplate}
sealed class Maybe<T> {
  const Maybe();

  /// Creates a [Maybe] from a nullable value.
  ///
  /// If the value is `null`, an [Absent] instance is returned. Otherwise, a
  /// [Present] instance containing the value is returned.
  static Maybe<T> from<T>(T? value) =>
      value == null ? const Absent() : Present(value);

  /// Resolves the [Maybe] into a single type.
  ///
  /// Returns the result of [onPresent] if the value is present, otherwise
  /// returns the result of [onAbsent].
  T2 resolve<T2>({
    required T2 Function(T value) onPresent,
    required T2 Function() onAbsent,
  }) => isPresent ? onPresent((this as Present<T>).value) : onAbsent();

  /// Changes the value if it is present, otherwise returns an [Absent].
  Maybe<T2> convert<T2>(T2 Function(T value) converter) => isPresent
      ? Present(converter((this as Present<T>).value))
      : const Absent();

  /// Returns the [Maybe] if the value is present and satisfies the [predicate],
  /// otherwise returns an [Absent].
  Maybe<T> filter(bool Function(T value) predicate) => isPresent
      ? predicate((this as Present<T>).value)
            ? this
            : const Absent()
      : this;

  /// Returns 'true' if the value is present, otherwise 'false'.
  bool get isPresent => this is Present<T>;

  /// Returns 'true' if the value is absent, otherwise 'false'.
  bool get isAbsent => this is Absent<T>;

  /// Returns the value if it is present, otherwise `null`.
  T? get asNullable =>
      resolve(onPresent: (value) => value, onAbsent: () => null);
}

/// {@template mallard.present}
///
/// Represents a present value.
///
/// {@endtemplate}
final class Present<T> extends Maybe<T> with EquatableMixin {
  /// {@macro mallard.present}
  const Present(this.value);

  /// The value being represented.
  final T value;

  @override
  List<Object?> get props => [value];
}

/// {@template mallard.absent}
///
/// Represents an absent value.
///
/// {@endtemplate}
final class Absent<T> extends Maybe<T> {
  /// {@macro mallard.absent}
  const Absent();
}

/// Creates an instance of [Absent].
Maybe<T> absent<T>() => const Absent();

/// Creates an instance of [Present] containing the provided [value].
Maybe<T> present<T>(T value) => Present(value);

/// Creates a [Maybe] from a nullable value.
///
/// If the value is not `null`, a [Present] instance containing the value is
/// returned. Otherwise, an [Absent] instance is returned.
///
/// {@macro mallard.maybe}
Maybe<T> maybe<T>(T? value) => Maybe.from(value);
