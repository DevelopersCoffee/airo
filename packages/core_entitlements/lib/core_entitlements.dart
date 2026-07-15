/// Entitlement and pro-module contracts for the Airo open-core split.
///
/// The open-source app depends only on this package. Pro implementations
/// live in the private `airo-pro` overlay and are swapped in via
/// `pubspec_overrides.yaml`, mirroring the existing `packages/stubs` pattern.
library;

export 'src/entitlements.dart';
export 'src/pro_module.dart';
