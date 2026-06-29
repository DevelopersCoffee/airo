import 'chess_engine.dart';
import '../models/chess_models.dart';

/// Stub chess engine for web platform (stockfish not supported)
class StubChessEngine with ChessEngineAsync implements ChessEngine {
  @override
  List<ChessMove> getLegalMoves() => [];

  @override
  bool makeMove(ChessMove move) => false;

  @override
  bool undoMove() => false;

  @override
  Future<ChessMove?> getBestMove({required ChessDifficulty difficulty}) async =>
      null;

  @override
  int evaluatePosition() => 0;

  @override
  bool isCheckmate() => false;

  @override
  bool isCheck() => false;

  @override
  bool isStalemate() => false;

  @override
  ChessBoardState getBoardState() => ChessBoardState.initial();

  @override
  void reset() {}

  @override
  String toFEN() => '';

  @override
  void fromFEN(String fen) {}

  /// Web stub - immediately ready (no Stockfish to wait for)
  @override
  Future<void> waitForReady() async {}
}
