import 'package:flutter/foundation.dart';

/// A modifier key participating in a [HotkeyCombination].
///
/// [meta] is the platform's "OS key" -- Command on macOS, the Windows key on
/// Windows, Super/Meta on Linux -- so one [HotkeyCombination] describes the
/// same physical chord across all three desktop platforms without the caller
/// branching on OS.
enum HotkeyModifier { meta, shift, control, alt }

/// A global hotkey chord: one or more modifiers plus a key.
///
/// Generic on purpose -- this type is shared by Quick Capture (#1454, the
/// default [quickCapture] chord) and the macOS Everything Browser's ⌘K
/// palette (#1461, its own chord), so neither feature's binding is baked in
/// here beyond the one both specs name explicitly.
@immutable
class HotkeyCombination {
  // Not asserted in the constructor: `modifiers.isEmpty` is not a constant
  // expression the analyzer can fold, which would make `quickCapture` below
  // (and every other const combination) fail to compile. Enforced instead by
  // [GlobalHotkeyRegistrar.register], which rejects an empty-modifier
  // request before it reaches a [GlobalHotkeyPort].
  const HotkeyCombination({required this.modifiers, required this.key});

  /// Quick Capture's binding: Cmd+Shift+Space on macOS, Win+Shift+Space on
  /// Windows and Linux ([HotkeyModifier.meta] maps to whichever key is the
  /// OS key on the running platform).
  static const HotkeyCombination quickCapture = HotkeyCombination(
    modifiers: {HotkeyModifier.meta, HotkeyModifier.shift},
    key: 'Space',
  );

  final Set<HotkeyModifier> modifiers;
  final String key;

  @override
  bool operator ==(Object other) =>
      other is HotkeyCombination &&
      other.key == key &&
      setEquals(other.modifiers, modifiers);

  @override
  int get hashCode => Object.hash(key, Object.hashAllUnordered(modifiers));

  @override
  String toString() {
    final sortedModifiers = modifiers.map((m) => m.name).toList()..sort();
    return [...sortedModifiers, key].join('+');
  }
}
