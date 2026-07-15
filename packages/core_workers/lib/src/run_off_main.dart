import 'dart:isolate';

/// Run [computation] on a worker isolate and return its result.
///
/// Policy: all parsing, serialization, and JSON decoding above ~50 KB must go
/// through this function. The Rust FFI core eventually replaces most call
/// sites, but the isolate boundary remains as rollback safety and web fallback.
///
/// Throws the original exception on failure (isolate errors are re-thrown).
Future<T> runOffMain<T>(T Function() computation) =>
    Isolate.run(computation);
