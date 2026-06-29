import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../platform/device_form_factor.dart';
import '../providers/platform_providers.dart';
import 'tv_focus_manager.dart';

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

/// TV-specific UI dimensions
class TvUiDimensions {
  /// Minimum touch/click target size
  final double minTargetSize;

  /// Card padding
  final double cardPadding;

  /// Grid spacing
  final double gridSpacing;

  /// Control button size
  final double controlButtonSize;

  /// Text scale factor for 10ft UI
  final double textScaleFactor;

  /// Channel card width
  final double channelCardWidth;

  /// Channel card height
  final double channelCardHeight;

  /// Focus border width
  final double focusBorderWidth;

  /// Safe zone padding (for Fire TV)
  final EdgeInsets safeZone;

  const TvUiDimensions._({
    required this.minTargetSize,
    required this.cardPadding,
    required this.gridSpacing,
    required this.controlButtonSize,
    required this.textScaleFactor,
    required this.channelCardWidth,
    required this.channelCardHeight,
    required this.focusBorderWidth,
    this.safeZone = EdgeInsets.zero,
  });

  /// TV dimensions (10ft UI) - Android TV
  factory TvUiDimensions.tv() => const TvUiDimensions._(
    minTargetSize: 56.0,
    cardPadding: 16.0,
    gridSpacing: 24.0,
    controlButtonSize: 64.0,
    textScaleFactor: 1.25,
    channelCardWidth: 200.0,
    channelCardHeight: 150.0,
    focusBorderWidth: 3.0,
  );

  /// Fire TV dimensions (10ft UI with Fire TV safe zones)
  factory TvUiDimensions.fireTv() => TvUiDimensions._(
    minTargetSize: 56.0,
    cardPadding: 16.0,
    gridSpacing: 24.0,
    controlButtonSize: 64.0,
    textScaleFactor: 1.25,
    channelCardWidth: 200.0,
    channelCardHeight: 150.0,
    focusBorderWidth: 3.0,
    safeZone: DeviceFormFactorDetector.getFireTvSafeZone(),
  );

  /// Mobile dimensions
  factory TvUiDimensions.mobile() => const TvUiDimensions._(
    minTargetSize: 48.0,
    cardPadding: 12.0,
    gridSpacing: 16.0,
    controlButtonSize: 48.0,
    textScaleFactor: 1.0,
    channelCardWidth: 140.0,
    channelCardHeight: 100.0,
    focusBorderWidth: 2.0,
  );
}

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
        return TvUiDimensions.fireTv();
      }
      return TvUiDimensions.tv();
    });
