import 'package:flutter/foundation.dart' show immutable;

/// Identifies a product shell that hosts shared modules.
///
/// This is intentionally a data value, not a fixed two-case enum, so that
/// adding a new shell (Airo Coins today, anything else tomorrow) never
/// requires changing this contract or any code that branches on it. Known
/// shells are exposed as `static const` values for convenience and equality,
/// but any code path may construct an arbitrary [ShellId] — for example a
/// test double shell, or a future modular app this package's authors never
/// anticipated.
@immutable
class ShellId {
  const ShellId(this.value);

  /// The mobile / phone-first super-app shell (`app/lib/main.dart`).
  static const mobile = ShellId('mobile');

  /// The Android TV / Fire TV shell (`app/lib/main_tv.dart`).
  static const tv = ShellId('tv');

  /// The Airo Coins shell (`app/lib/main_coins.dart`), introduced alongside
  /// this contract. No production UI ships behind this identifier yet.
  static const coins = ShellId('coins');

  /// Stable, lowercase identifier for this shell (used for equality, logs,
  /// and any future serialization — never for display).
  final String value;

  @override
  bool operator ==(Object other) => other is ShellId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'ShellId($value)';
}
