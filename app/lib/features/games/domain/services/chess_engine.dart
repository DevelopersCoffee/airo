import '../models/chess_models.dart';

/// Mixin for engines that need async initialization
mixin ChessEngineAsync {
  Future<void> waitForReady();
}

/// Difficulty level for AI
enum ChessDifficulty {
  easy(depthLimit: 2, randomness: 0.3),
  medium(depthLimit: 4, randomness: 0.1),
  hard(depthLimit: 6, randomness: 0.0),
  expert(depthLimit: 20, randomness: 0.0); // World champion level

  final int depthLimit;
  final double randomness;

  const ChessDifficulty({required this.depthLimit, required this.randomness});
}

/// Chess engine interface
abstract class ChessEngine {
  /// Get legal moves for current position
  List<ChessMove> getLegalMoves();

  /// Make a move on the board
  bool makeMove(ChessMove move);

  /// Undo last move
  bool undoMove();

  /// Get best move for AI
  Future<ChessMove?> getBestMove({required ChessDifficulty difficulty});

  /// Evaluate position (positive = white advantage, negative = black advantage)
  int evaluatePosition();

  /// Check if position is checkmate
  bool isCheckmate();

  /// Check if position is check
  bool isCheck();

  /// Check if position is stalemate
  bool isStalemate();

  /// Get current board state
  ChessBoardState getBoardState();

  /// Reset to initial position
  void reset();

  /// Get FEN string
  String toFEN();

  /// Load from FEN string
  void fromFEN(String fen);
}
