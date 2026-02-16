import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../platform/device_form_factor.dart';

/// Provider for device form factor detection
///
/// Returns cached device form factor for UI adaptation.
/// Used for TV preparation (TV-P0-6: 10ft UI scaling).
///
/// Usage:
/// ```dart
/// final formFactor = ref.watch(deviceFormFactorProvider);
/// if (formFactor == DeviceFormFactor.tv) {
///   // Render TV-optimized UI
/// }
/// ```
///
/// Note: This provider returns synchronous result using screen-based
/// detection. For async TV detection with platform channels, use
/// `deviceFormFactorAsyncProvider` with a context.
final deviceFormFactorProvider = Provider<DeviceFormFactor>((ref) {
  // Default to mobile since we don't have context here
  // Widgets should use deviceFormFactorSyncProvider with context
  return DeviceFormFactor.mobile;
});

/// Provider family for synchronous form factor detection with context
///
/// Usage:
/// ```dart
/// Widget build(BuildContext context, WidgetRef ref) {
///   final formFactor = ref.watch(deviceFormFactorSyncProvider(context));
///   // ...
/// }
/// ```
final deviceFormFactorSyncProvider =
    Provider.family<DeviceFormFactor, BuildContext>((ref, context) {
  return DeviceFormFactorDetector.detectSync(context);
});

/// Async provider for full TV detection (uses platform channels)
///
/// Usage:
/// ```dart
/// Widget build(BuildContext context, WidgetRef ref) {
///   final formFactorAsync = ref.watch(deviceFormFactorAsyncProvider(context));
///   return formFactorAsync.when(
///     data: (formFactor) => _buildForFormFactor(formFactor),
///     loading: () => _buildForFormFactor(DeviceFormFactor.mobile),
///     error: (_, _) => _buildForFormFactor(DeviceFormFactor.mobile),
///   );
/// }
/// ```
final deviceFormFactorAsyncProvider =
    FutureProvider.family<DeviceFormFactor, BuildContext?>((ref, context) {
  return DeviceFormFactorDetector.detect(context);
});

/// Provider for checking if current device is TV
///
/// Convenience provider for TV-specific UI branches.
/// Usage:
/// ```dart
/// final isTV = ref.watch(isTvDeviceProvider(context));
/// ```
final isTvDeviceProvider = Provider.family<bool, BuildContext>((ref, context) {
  final formFactor = ref.watch(deviceFormFactorSyncProvider(context));
  return formFactor == DeviceFormFactor.tv;
});

/// Provider for minimum touch target size
///
/// Returns 56dp for TV, 48dp for other devices.
/// Usage:
/// ```dart
/// final minTarget = ref.watch(minTouchTargetProvider(context));
/// ```
final minTouchTargetProvider =
    Provider.family<double, BuildContext>((ref, context) {
  final formFactor = ref.watch(deviceFormFactorSyncProvider(context));
  return DeviceFormFactorDetector.getMinTouchTarget(formFactor);
});

/// Provider for D-pad navigation support
///
/// Returns true for TV devices.
/// Usage:
/// ```dart
/// final needsDpad = ref.watch(supportsDpadNavigationProvider(context));
/// ```
final supportsDpadNavigationProvider =
    Provider.family<bool, BuildContext>((ref, context) {
  final formFactor = ref.watch(deviceFormFactorSyncProvider(context));
  return DeviceFormFactorDetector.supportsDpadNavigation(formFactor);
});

