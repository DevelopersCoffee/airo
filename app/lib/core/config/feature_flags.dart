/// Feature flags for the Airo Super App
///
/// These flags control the visibility and behavior of experimental features.
/// Set via compile-time constants or environment variables.
library;

/// Enable performance monitoring overlay
///
/// Shows FPS counter and memory usage in debug builds.
const bool kEnablePerformanceOverlay = bool.fromEnvironment(
  'ENABLE_PERF_OVERLAY',
  defaultValue: false,
);

/// Enable the experimental phone-local media handoff entry point.
///
/// This stays off in normal builds until the Airo Receiver qualification
/// matrix and launch gate are complete.
const bool kEnablePhoneMediaReceiverExperimental = bool.fromEnvironment(
  'ENABLE_PHONE_MEDIA_RECEIVER',
  defaultValue: false,
);
