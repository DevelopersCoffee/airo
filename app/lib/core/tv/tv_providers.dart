import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../platform/device_form_factor.dart';
import '../providers/platform_providers.dart';

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

/// Provider for checking if TV mode is active
///
/// Returns true when running on Android TV or Fire TV.
/// Usage:
/// ```dart
/// if (ref.watch(isTvModeProvider(context))) {
///   return TvChannelGrid();
/// } else {
///   return MobileChannelList();
/// }
/// ```
final isTvModeProvider = Provider.family<bool, BuildContext>((ref, context) {
  return ref.watch(isTvDeviceProvider(context));
});

/// Provider for TV UI dimensions
///
/// Returns TV-specific dimensions for 10ft UI.
final tvDimensionsProvider = Provider.family<TvUiDimensions, BuildContext>((
  ref,
  context,
) {
  final isTV = ref.watch(isTvModeProvider(context));
  return isTV ? TvUiDimensions.tv() : TvUiDimensions.mobile();
});

/// Provider for current focus section
final currentFocusSectionProvider = Provider<String?>((ref) {
  final manager = ref.watch(tvFocusManagerProvider);
  return manager.currentSectionId;
});

/// Provider for TV navigation hints visibility
///
/// Shows navigation hints like "Press OK to select" on TV.
final showTvHintsProvider = Provider.family<bool, BuildContext>((ref, context) {
  return ref.watch(isTvModeProvider(context));
});

/// Provider for TV UI dimensions with Fire TV support
///
/// Uses async platform detection to provide Fire TV specific dimensions.
/// Falls back to standard TV dimensions while loading.
///
/// Usage:
/// ```dart
/// final dimensions = ref.watch(tvDimensionsWithFireTvProvider(context));
/// return dimensions.when(
///   data: (dims) => Padding(padding: dims.safeZone, child: content),
///   loading: () => _buildWithDefaultDimensions(),
///   error: (_, _) => _buildWithDefaultDimensions(),
/// );
/// ```
final tvDimensionsWithFireTvProvider =
    FutureProvider.family<TvUiDimensions, BuildContext>((ref, context) async {
      final isTV = ref.watch(isTvModeProvider(context));
      if (!isTV) return TvUiDimensions.mobile();

      final tvPlatform = await ref.watch(tvPlatformProvider.future);
      if (tvPlatform == TvPlatform.fireTv) {
        return TvUiDimensions.tv(
          safeZone: DeviceFormFactorDetector.getFireTvSafeZone(),
        );
      }
      return TvUiDimensions.tv();
    });
