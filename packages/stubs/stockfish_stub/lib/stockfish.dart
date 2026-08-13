/// Stub implementation of Stockfish for TV builds
/// This stub provides the same API but with no-op implementations
/// to avoid bundling the 108MB native library

import 'dart:async';

/// Stub Stockfish class
class Stockfish {
  /// Stub stdin - ignores all input
  set stdin(String command) {
    // No-op: Stockfish not available on TV
  }

  /// Stub stdout - returns empty stream
  Stream<String> get stdout => const Stream.empty();

  /// Stub state. Reports `error` rather than `ready`: this build carries no
  /// native engine, `stdout` never emits, and a caller polling for a UCI
  /// handshake response would otherwise wait out its full timeout on every
  /// game start before falling back (see issue #1407).
  StockfishState get state => StockfishState.error;

  /// Dispose the engine
  void dispose() {
    // No-op
  }
}

/// Stockfish state enum
enum StockfishState { starting, ready, disposed, error }
