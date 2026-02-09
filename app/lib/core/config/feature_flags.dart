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
