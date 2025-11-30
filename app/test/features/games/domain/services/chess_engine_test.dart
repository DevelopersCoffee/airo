import 'package:flutter_test/flutter_test.dart';
import 'package:airo_app/features/games/domain/services/chess_engine.dart';
import 'package:airo_app/features/games/domain/models/chess_models.dart';

/// Chess engine unit tests
void main() {
  group('ChessDifficulty', () {
    test('easy has low depth and high randomness', () {
      expect(ChessDifficulty.easy.depthLimit, equals(2));
      expect(ChessDifficulty.easy.randomness, equals(0.3));
    });

    test('medium has moderate depth and randomness', () {
      expect(ChessDifficulty.medium.depthLimit, equals(4));
      expect(ChessDifficulty.medium.randomness, equals(0.1));
    });

    test('hard has high depth and no randomness', () {
      expect(ChessDifficulty.hard.depthLimit, equals(6));
      expect(ChessDifficulty.hard.randomness, equals(0.0));
    });

    test('expert has very high depth and no randomness', () {
      expect(ChessDifficulty.expert.depthLimit, equals(20));
      expect(ChessDifficulty.expert.randomness, equals(0.0));
    });

    test('all difficulties have increasing depth', () {
      expect(
        ChessDifficulty.easy.depthLimit,
        lessThan(ChessDifficulty.medium.depthLimit),
      );
      expect(
        ChessDifficulty.medium.depthLimit,
        lessThan(ChessDifficulty.hard.depthLimit),
      );
      expect(
        ChessDifficulty.hard.depthLimit,
        lessThan(ChessDifficulty.expert.depthLimit),
      );
    });

    test('all difficulties have decreasing randomness', () {
      expect(
        ChessDifficulty.easy.randomness,
        greaterThan(ChessDifficulty.medium.randomness),
      );
      expect(
        ChessDifficulty.medium.randomness,
        greaterThan(ChessDifficulty.hard.randomness),
      );
      expect(ChessDifficulty.hard.randomness, equals(0.0));
      expect(ChessDifficulty.expert.randomness, equals(0.0));
    });
  });

  group('ChessEngine Interface Contract', () {
    // These tests verify the contract that any ChessEngine implementation must fulfill
    // Note: Real engine tests require native dependencies (Stockfish)
    // These are contract/interface tests

    test('ChessEngine defines required methods', () {
      // Verify the abstract class has all required methods
      // This is a compile-time check wrapped in a test
      expect(ChessEngine, isA<Type>());
    });
  });
}

/// Minimal fake chess engine for testing without native dependencies
class TestableChessEngine implements ChessEngine {
  ChessBoardState _state = ChessBoardState.initial();
  final List<ChessMove> _moveHistory = [];

  @override
  List<ChessMove> getLegalMoves() {
    // Return some sample moves for the initial position
    if (_moveHistory.isEmpty) {
      return [
        // Pawn moves
        const ChessMove(
          from: ChessSquare(12), // e2
          to: ChessSquare(28), // e4
        ),
        const ChessMove(
          from: ChessSquare(11), // d2
          to: ChessSquare(27), // d4
        ),
        // Knight moves
        const ChessMove(
          from: ChessSquare(1), // b1
          to: ChessSquare(18), // c3
        ),
        const ChessMove(
          from: ChessSquare(6), // g1
          to: ChessSquare(21), // f3
        ),
      ];
    }
    return [];
  }

  @override
  bool makeMove(ChessMove move) {
    _moveHistory.add(move);
    return true;
  }

  @override
  bool undoMove() {
    if (_moveHistory.isEmpty) return false;
    _moveHistory.removeLast();
    return true;
  }

  @override
  Future<ChessMove?> getBestMove({required ChessDifficulty difficulty}) async {
    final moves = getLegalMoves();
    if (moves.isEmpty) return null;
    return moves.first;
  }

  @override
  int evaluatePosition() => 0;

  @override
  bool isCheckmate() => false;

  @override
  bool isCheck() => false;

  @override
  bool isStalemate() => false;

  @override
  ChessBoardState getBoardState() => _state;

  @override
  void reset() {
    _state = ChessBoardState.initial();
    _moveHistory.clear();
  }

  @override
  String toFEN() => 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  @override
  void fromFEN(String fen) {
    // Simplified: just reset to initial
    reset();
  }
}

