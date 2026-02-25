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

  /// Stub state
  StockfishState get state => StockfishState.ready;

  /// Dispose the engine
  void dispose() {
    // No-op
  }
}

/// Stockfish state enum
enum StockfishState {
  starting,
  ready,
  disposed,
  error,
}

