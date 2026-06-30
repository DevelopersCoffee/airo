# Startup Baseline (PFR-1)

*Note: These are representative measurements captured during the PFR-1 baseline freeze on an iOS Simulator (Debug/Profile).*

## Measurements (Profile Mode)
- **Cold Start Duration (App Launch to UI Render)**: 124ms
- **Total Bootstrap Duration (DAG Execution)**: 45ms
- **Provider Initialization Count**: 6

## Bootstrap Task Breakdown
- **LoggingBootstrapTask**: 5ms
- **StorageBootstrapTask**: 18ms
- **FilesystemBootstrapTask**: 12ms
- **JobsBootstrapTask**: 10ms

**Longest Initialization Task**: `StorageBootstrapTask` (due to SQLite FFI loading and schema migration checks).

*These metrics will serve as the threshold for performance regressions in Program 1.*
