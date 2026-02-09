import 'package:flutter/material.dart';

/// Media hub mode selection
enum MediaMode {
  music('Music', Icons.music_note),
  tv('TV', Icons.live_tv);

  const MediaMode(this.label, this.icon);

  /// Display label for the mode
  final String label;

  /// Icon for the mode
  final IconData icon;

  /// Check if this is music mode
  bool get isMusic => this == MediaMode.music;

  /// Check if this is TV mode
  bool get isTV => this == MediaMode.tv;
}

