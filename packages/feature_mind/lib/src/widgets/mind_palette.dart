import 'package:flutter/painting.dart';

/// The Airo Mind device system's palette.
///
/// Distinct from `AppColors.cyber*` in core_ui, which is the Living Console
/// palette: that one is #5CE1E6 on #F4F1EA, this one is #7FE8DE on #FFE6CB.
/// They are two visual languages, not one with drift, and collapsing them
/// would change every Mind surface away from what the design specifies.
///
/// Kept here rather than widened into core_ui because it dresses one module.
/// Move it up the moment a second module needs it.
abstract final class MindPalette {
  /// Work that happened on this device. Rule R01's teal.
  static const Color local = Color(0xFF7FE8DE);

  /// Work that happened on another device the person owns.
  static const Color remote = Color(0xFFFFFF89);

  /// Body and label ink.
  static const Color ink = Color(0xFFFFE6CB);

  /// Ink on a filled surface.
  static const Color onFilled = Color(0xFF041C1C);

  /// A signature that did not verify. Loud on purpose: it is the one state a
  /// person must not scroll past.
  static const Color alarm = Color(0xFFFF6B6B);
}
