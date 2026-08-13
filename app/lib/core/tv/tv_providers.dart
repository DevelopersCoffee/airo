import 'package:core_ui/core_ui.dart';
import 'package:flutter_riverpod/legacy.dart';

/// Provider for TV Focus Manager
///
/// Central focus manager for TV navigation.
/// Usage:
/// ```dart
/// final focusManager = ref.watch(tvFocusManagerProvider);
/// focusManager.focusSection('player_controls');
/// ```
final tvFocusManagerProvider = ChangeNotifierProvider<TvFocusManager>((ref) {
  return TvFocusManager();
});
