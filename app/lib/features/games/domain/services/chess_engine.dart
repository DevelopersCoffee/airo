import '../models/chess_models.dart';

/// Difficulty level for AI
enum ChessDifficulty {
  easy(depthLimit: 2, randomness: 0.3),
  medium(depthLimit: 4, randomness: 0.1),
  hard(depthLimit: 6, randomness: 0.0);

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

/// Fake chess engine for development
class FakeChessEngine implements ChessEngine {
  late ChessBoardState _board;

  FakeChessEngine() {
    _board = ChessBoardState.initial();
  }

  @override
  List<ChessMove> getLegalMoves() {
    // Simplified: return some pseudo-legal moves
    final moves = <ChessMove>[];
    for (int i = 0; i < 64; i++) {
      final piece = _board.squares[i];
      if (piece == null || piece.color != _board.toMove) continue;

      // Generate moves based on piece type
      switch (piece.type) {
        case PieceType.pawn:
          moves.addAll(_getPawnMoves(i));
        case PieceType.knight:
          moves.addAll(_getKnightMoves(i));
        case PieceType.bishop:
          moves.addAll(_getBishopMoves(i));
        case PieceType.rook:
          moves.addAll(_getRookMoves(i));
        case PieceType.queen:
          moves.addAll(_getQueenMoves(i));
        case PieceType.king:
          moves.addAll(_getKingMoves(i));
      }
    }
    return moves;
  }

  List<ChessMove> _getPawnMoves(int index) {
    final moves = <ChessMove>[];
    final piece = _board.squares[index]!;
    final direction = piece.color == ChessColor.white ? 1 : -1;
    final startRank = piece.color == ChessColor.white ? 1 : 6;

    // Forward move
    final forwardIndex = index + direction * 8;
    if (forwardIndex >= 0 && forwardIndex < 64) {
      if (_board.squares[forwardIndex] == null) {
        moves.add(
          ChessMove(from: ChessSquare(index), to: ChessSquare(forwardIndex)),
        );
      }
    }

    // Captures
    for (int offset in [-1, 1]) {
      final captureIndex = index + direction * 8 + offset;
      if (captureIndex >= 0 && captureIndex < 64) {
        final target = _board.squares[captureIndex];
        if (target != null && target.color != piece.color) {
          moves.add(
            ChessMove(from: ChessSquare(index), to: ChessSquare(captureIndex)),
          );
        }
      }
    }

    return moves;
  }

  List<ChessMove> _getKnightMoves(int index) {
    final moves = <ChessMove>[];
    final offsets = [-17, -15, -10, -6, 6, 10, 15, 17];
    for (final offset in offsets) {
      final targetIndex = index + offset;
      if (targetIndex >= 0 && targetIndex < 64) {
        final target = _board.squares[targetIndex];
        if (target == null || target.color != _board.squares[index]!.color) {
          moves.add(
            ChessMove(from: ChessSquare(index), to: ChessSquare(targetIndex)),
          );
        }
      }
    }
    return moves;
  }

  List<ChessMove> _getBishopMoves(int index) =>
      _getSlidingMoves(index, [-9, -7, 7, 9]);
  List<ChessMove> _getRookMoves(int index) =>
      _getSlidingMoves(index, [-8, -1, 1, 8]);
  List<ChessMove> _getQueenMoves(int index) =>
      _getSlidingMoves(index, [-9, -8, -7, -1, 1, 7, 8, 9]);

  List<ChessMove> _getSlidingMoves(int index, List<int> directions) {
    final moves = <ChessMove>[];
    for (final direction in directions) {
      var targetIndex = index + direction;
      while (targetIndex >= 0 && targetIndex < 64) {
        final target = _board.squares[targetIndex];
        if (target == null) {
          moves.add(
            ChessMove(from: ChessSquare(index), to: ChessSquare(targetIndex)),
          );
        } else {
          if (target.color != _board.squares[index]!.color) {
            moves.add(
              ChessMove(from: ChessSquare(index), to: ChessSquare(targetIndex)),
            );
          }
          break;
        }
        targetIndex += direction;
      }
    }
    return moves;
  }

  List<ChessMove> _getKingMoves(int index) {
    final moves = <ChessMove>[];
    final offsets = [-9, -8, -7, -1, 1, 7, 8, 9];
    for (final offset in offsets) {
      final targetIndex = index + offset;
      if (targetIndex >= 0 && targetIndex < 64) {
        final target = _board.squares[targetIndex];
        if (target == null || target.color != _board.squares[index]!.color) {
          moves.add(
            ChessMove(from: ChessSquare(index), to: ChessSquare(targetIndex)),
          );
        }
      }
    }
    return moves;
  }

  @override
  bool makeMove(ChessMove move) {
    final piece = _board.squares[move.from.index];
    if (piece == null) return false;

    final newSquares = List<ChessPiece?>.from(_board.squares);
    newSquares[move.to.index] = piece;
    newSquares[move.from.index] = null;

    final newToMove = _board.toMove == ChessColor.white
        ? ChessColor.black
        : ChessColor.white;
    final newMoveHistory = [..._board.moveHistory, move];

    _board = ChessBoardState(
      squares: newSquares,
      toMove: newToMove,
      whiteCanCastleKingside: _board.whiteCanCastleKingside,
      whiteCanCastleQueenside: _board.whiteCanCastleQueenside,
      blackCanCastleKingside: _board.blackCanCastleKingside,
      blackCanCastleQueenside: _board.blackCanCastleQueenside,
      enPassantSquare: null,
      halfmoveClock: _board.halfmoveClock + 1,
      fullmoveNumber: newToMove == ChessColor.white
          ? _board.fullmoveNumber + 1
          : _board.fullmoveNumber,
      moveHistory: newMoveHistory,
    );

    return true;
  }

  @override
  bool undoMove() {
    if (_board.moveHistory.isEmpty) return false;
    _board = ChessBoardState.initial();
    for (int i = 0; i < _board.moveHistory.length - 1; i++) {
      makeMove(_board.moveHistory[i]);
    }
    return true;
  }

  @override
  Future<ChessMove?> getBestMove({required ChessDifficulty difficulty}) async {
    final moves = getLegalMoves();
    if (moves.isEmpty) return null;

    // Add randomness for easier difficulties
    if (difficulty.randomness > 0 && moves.length > 1) {
      final random = DateTime.now().millisecond % moves.length;
      if (random < moves.length * difficulty.randomness) {
        return moves[random];
      }
    }

    return moves.first;
  }

  @override
  int evaluatePosition() => 0; // Neutral

  @override
  bool isCheckmate() => false;

  @override
  bool isCheck() => false;

  @override
  bool isStalemate() => false;

  @override
  ChessBoardState getBoardState() => _board;

  @override
  void reset() => _board = ChessBoardState.initial();

  @override
  String toFEN() => 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  @override
  void fromFEN(String fen) => _board = ChessBoardState.initial();
}
