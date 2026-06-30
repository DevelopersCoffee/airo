import 'dart:io' show Platform;

import 'chess_engine.dart';
import 'chess_engine_stub.dart';
import 'real_chess_engine.dart';

/// Creates a chess engine based on the platform.
///
/// On iOS, uses StubChessEngine because the stockfish package has
/// NNUE file embedding issues on iOS (see stockfish issue #51).
/// On Android and desktop, uses RealChessEngine with full Stockfish support.
ChessEngine createChessEngine() {
  if (Platform.isIOS) {
    // iOS: Use stub engine due to stockfish NNUE file issues
    // The stockfish package fails to compile on iOS because it can't find
    // the embedded NNUE neural network files (nn-*.nnue)
    return StubChessEngine();
  }
  // Android and desktop: Use real Stockfish engine
  return RealChessEngine();
}
