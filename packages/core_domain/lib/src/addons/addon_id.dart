import 'package:meta/meta.dart';

@immutable
class AddonId {
  const AddonId(this.value);

  final String value;

  @override
  bool operator ==(Object other) =>
      other is AddonId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
