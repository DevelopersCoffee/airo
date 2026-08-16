import 'package:flutter/material.dart';

/// Color-blind-safe speaker chip palette (Paul Tol–style distinct hues).
///
/// Indexed by `spN` numeric suffix; wraps when meetings exceed palette length.
const List<Color> kMindSpeakerPalette = [
  Color(0xFF0072B2), // blue
  Color(0xFFE69F00), // orange
  Color(0xFF009E73), // green
  Color(0xFFCC79A7), // reddish purple
  Color(0xFF56B4E9), // sky blue
  Color(0xFFD55E00), // vermillion
  Color(0xFF000000), // black
];

/// Parses `sp0` → `0`. Non-matching labels map to `0`.
int mindSpeakerPaletteIndex(String label) {
  final match = RegExp(r'^sp(\d+)$').firstMatch(label);
  if (match == null) return 0;
  return int.parse(match.group(1)!);
}

Color mindSpeakerChipColor(String label) {
  final index = mindSpeakerPaletteIndex(label);
  return kMindSpeakerPalette[index % kMindSpeakerPalette.length];
}

Color mindSpeakerChipForeground(Color background) {
  // Black chip needs a light label; others use near-white on saturated hues.
  if (background == const Color(0xFF000000)) {
    return const Color(0xFFF5F5F5);
  }
  return const Color(0xFFFAFAFA);
}
