import 'package:flutter_test/flutter_test.dart';
import 'package:airo_app/features/games/domain/models/chess_models.dart';
import 'package:airo_app/features/games/domain/services/chess_engine.dart';
import 'package:chess/chess.dart' as chess_lib;

/// Test chess engine that wraps chess.dart for unit testing
/// without requiring Stockfish (which needs native code)
class TestChessEngine implements ChessEngine {
  final chess_lib.Chess _chess;

  TestChessEngine() : _chess = chess_lib.Chess();

  TestChessEngine.fromFEN(String fen) : _chess = chess_lib.Chess.fromFEN(fen);

  @override
  List<ChessMove> getLegalMoves() {
    final moves = _chess.moves({'verbose': true});
    return moves.map((m) => _convertMove(m)).toList();
  }

  @override
  bool makeMove(ChessMove move) {
    final moveStr = _toAlgebraic(move);
    return _chess.move(moveStr);
  }

  @override
  bool undoMove() => _chess.undo_move() != null;

  @override
  Future<ChessMove?> getBestMove({required ChessDifficulty difficulty}) async {
    final moves = getLegalMoves();
    return moves.isNotEmpty ? moves.first : null;
  }

  @override
  int evaluatePosition() => 0;

  @override
  bool isCheckmate() => _chess.in_checkmate;

  @override
  bool isCheck() => _chess.in_check;

  @override
  bool isStalemate() => _chess.in_stalemate;

  @override
  ChessBoardState getBoardState() {
    final squares = List<ChessPiece?>.filled(64, null);
    final board = _chess.board;

    for (int i = 0; i < board.length; i++) {
      final piece = board[i];
      if (piece != null) {
        final rank = i ~/ 16;
        final file = i % 16;
        if (file < 8) {
          final index = rank * 8 + file;
          if (index < 64) {
            squares[index] = ChessPiece(
              type: _convertPieceType(piece.type),
              color: piece.color == chess_lib.Color.WHITE
                  ? ChessColor.white
                  : ChessColor.black,
            );
          }
        }
      }
    }

    return ChessBoardState(
      squares: squares,
      toMove: _chess.turn == chess_lib.Color.WHITE
          ? ChessColor.white
          : ChessColor.black,
      whiteCanCastleKingside: _chess.fen.contains('K'),
      whiteCanCastleQueenside: _chess.fen.contains('Q'),
      blackCanCastleKingside: _chess.fen.contains('k'),
      blackCanCastleQueenside: _chess.fen.contains('q'),
      enPassantSquare: null,
      halfmoveClock: 0,
      fullmoveNumber: 1,
      moveHistory: [],
    );
  }

  @override
  void reset() => _chess.reset();

  @override
  String toFEN() => _chess.fen;

  @override
  void fromFEN(String fen) => _chess.load(fen);

  ChessMove _convertMove(dynamic move) {
    final from = _squareToIndex(move['from'] as String);
    final to = _squareToIndex(move['to'] as String);
    final promotion = move['promotion'] != null
        ? _convertPieceTypeFromString(move['promotion'] as String)
        : null;
    return ChessMove(
      from: ChessSquare(from),
      to: ChessSquare(to),
      promotion: promotion,
    );
  }

  int _squareToIndex(String square) {
    final file = square.codeUnitAt(0) - 'a'.codeUnitAt(0);
    final rank = int.parse(square[1]) - 1;
    return rank * 8 + file;
  }

  String _indexToSquare(int index) {
    final file = String.fromCharCode('a'.codeUnitAt(0) + (index % 8));
    final rank = (index ~/ 8 + 1).toString();
    return '$file$rank';
  }

  String _toAlgebraic(ChessMove move) {
    final from = _indexToSquare(move.from.index);
    final to = _indexToSquare(move.to.index);
    final promotion =
        move.promotion != null ? _pieceTypeToChar(move.promotion!) : '';
    return '$from$to$promotion';
  }

  PieceType _convertPieceTypeFromString(String type) {
    switch (type.toLowerCase()) {
      case 'n':
        return PieceType.knight;
      case 'b':
        return PieceType.bishop;
      case 'r':
        return PieceType.rook;
      case 'q':
        return PieceType.queen;
      case 'k':
        return PieceType.king;
      default:
        return PieceType.pawn;
    }
  }

  PieceType _convertPieceType(chess_lib.PieceType type) {
    return switch (type) {
      chess_lib.PieceType.PAWN => PieceType.pawn,
      chess_lib.PieceType.KNIGHT => PieceType.knight,
      chess_lib.PieceType.BISHOP => PieceType.bishop,
      chess_lib.PieceType.ROOK => PieceType.rook,
      chess_lib.PieceType.QUEEN => PieceType.queen,
      chess_lib.PieceType.KING => PieceType.king,
      _ => PieceType.pawn,
    };
  }

  String _pieceTypeToChar(PieceType type) {
    switch (type) {
      case PieceType.knight:
        return 'n';
      case PieceType.bishop:
        return 'b';
      case PieceType.rook:
        return 'r';
      case PieceType.queen:
        return 'q';
      case PieceType.king:
        return 'k';
      default:
        return 'p';
    }
  }
}

void main() {
  group('Chess Engine Edge Cases', () {
    group('Castling', () {
      test('white can castle kingside', () {
        // Position where white can castle kingside
        final engine = TestChessEngine.fromFEN(
          'r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w KQkq - 0 1',
        );
        final moves = engine.getLegalMoves();
        final castleMove = moves.where(
          (m) => m.from.index == 4 && m.to.index == 6, // e1 to g1
        );
        expect(castleMove, isNotEmpty, reason: 'Kingside castle should be legal');
      });

      test('white can castle queenside', () {
        final engine = TestChessEngine.fromFEN(
          'r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w KQkq - 0 1',
        );
        final moves = engine.getLegalMoves();
        final castleMove = moves.where(
          (m) => m.from.index == 4 && m.to.index == 2, // e1 to c1
        );
        expect(castleMove, isNotEmpty, reason: 'Queenside castle should be legal');
      });

      test('black can castle kingside', () {
        final engine = TestChessEngine.fromFEN(
          'r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R b KQkq - 0 1',
        );
        final moves = engine.getLegalMoves();
        final castleMove = moves.where(
          (m) => m.from.index == 60 && m.to.index == 62, // e8 to g8
        );
        expect(castleMove, isNotEmpty, reason: 'Black kingside castle should be legal');
      });

      test('black can castle queenside', () {
        final engine = TestChessEngine.fromFEN(
          'r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R b KQkq - 0 1',
        );
        final moves = engine.getLegalMoves();
        final castleMove = moves.where(
          (m) => m.from.index == 60 && m.to.index == 58, // e8 to c8
        );
        expect(castleMove, isNotEmpty, reason: 'Black queenside castle should be legal');
      });

      test('cannot castle through check', () {
        // Bishop on b4 attacks e1-g1 path
        final engine = TestChessEngine.fromFEN(
          'r3k2r/pppppppp/8/8/1b6/8/PPPPPPPP/R3K2R w KQkq - 0 1',
        );
        final moves = engine.getLegalMoves();
        final castleMove = moves.where(
          (m) => m.from.index == 4 && m.to.index == 6, // e1 to g1
        );
        expect(castleMove, isEmpty, reason: 'Cannot castle through check');
      });

      test('cannot castle when king has moved', () {
        final engine = TestChessEngine.fromFEN(
          'r3k2r/pppppppp/8/8/8/8/PPPPPPPP/R3K2R w Qkq - 0 1', // No K right
        );
        final moves = engine.getLegalMoves();
        final castleMove = moves.where(
          (m) => m.from.index == 4 && m.to.index == 6, // e1 to g1
        );
        expect(castleMove, isEmpty, reason: 'Cannot castle after king moved');
      });
    });

    group('En Passant', () {
      test('white can capture en passant', () {
        // White pawn on e5, black just moved d7-d5
        final engine = TestChessEngine.fromFEN(
          'rnbqkbnr/ppp1pppp/8/3pP3/8/8/PPPP1PPP/RNBQKBNR w KQkq d6 0 1',
        );
        final moves = engine.getLegalMoves();
        final epMove = moves.where(
          (m) => m.from.index == 36 && m.to.index == 43, // e5 to d6
        );
        expect(epMove, isNotEmpty, reason: 'En passant should be legal');
      });

      test('black can capture en passant', () {
        // Black pawn on d4, white just moved e2-e4
        final engine = TestChessEngine.fromFEN(
          'rnbqkbnr/pppp1ppp/8/8/3pP3/8/PPP2PPP/RNBQKBNR b KQkq e3 0 1',
        );
        final moves = engine.getLegalMoves();
        final epMove = moves.where(
          (m) => m.from.index == 27 && m.to.index == 20, // d4 to e3
        );
        expect(epMove, isNotEmpty, reason: 'Black en passant should be legal');
      });

      test('en passant only valid immediately after pawn advance', () {
        // Same position but no en passant square set
        final engine = TestChessEngine.fromFEN(
          'rnbqkbnr/ppp1pppp/8/3pP3/8/8/PPPP1PPP/RNBQKBNR w KQkq - 0 1',
        );
        final moves = engine.getLegalMoves();
        final epMove = moves.where(
          (m) => m.from.index == 36 && m.to.index == 43, // e5 to d6
        );
        expect(epMove, isEmpty, reason: 'EP not valid without ep square');
      });
    });

    group('Pawn Promotion', () {
      test('pawn can promote to queen', () {
        final engine = TestChessEngine.fromFEN(
          '8/P7/8/8/8/8/8/4K2k w - - 0 1',
        );
        final moves = engine.getLegalMoves();
        final promoMoves = moves.where(
          (m) => m.from.index == 48 && m.to.index == 56 && m.promotion == PieceType.queen,
        );
        expect(promoMoves, isNotEmpty, reason: 'Queen promotion should be available');
      });

      test('pawn can promote to knight', () {
        final engine = TestChessEngine.fromFEN(
          '8/P7/8/8/8/8/8/4K2k w - - 0 1',
        );
        final moves = engine.getLegalMoves();
        final promoMoves = moves.where(
          (m) => m.from.index == 48 && m.to.index == 56 && m.promotion == PieceType.knight,
        );
        expect(promoMoves, isNotEmpty, reason: 'Knight promotion should be available');
      });

      test('pawn can promote to rook', () {
        final engine = TestChessEngine.fromFEN(
          '8/P7/8/8/8/8/8/4K2k w - - 0 1',
        );
        final moves = engine.getLegalMoves();
        final promoMoves = moves.where(
          (m) => m.from.index == 48 && m.to.index == 56 && m.promotion == PieceType.rook,
        );
        expect(promoMoves, isNotEmpty, reason: 'Rook promotion should be available');
      });

      test('pawn can promote to bishop', () {
        final engine = TestChessEngine.fromFEN(
          '8/P7/8/8/8/8/8/4K2k w - - 0 1',
        );
        final moves = engine.getLegalMoves();
        final promoMoves = moves.where(
          (m) => m.from.index == 48 && m.to.index == 56 && m.promotion == PieceType.bishop,
        );
        expect(promoMoves, isNotEmpty, reason: 'Bishop promotion should be available');
      });

      test('promotion with capture', () {
        final engine = TestChessEngine.fromFEN(
          '1n6/P7/8/8/8/8/8/4K2k w - - 0 1',
        );
        final moves = engine.getLegalMoves();
        final promoCaptures = moves.where(
          (m) => m.from.index == 48 && m.to.index == 57 && m.promotion != null,
        );
        expect(promoCaptures.length, equals(4), reason: 'All 4 promotion types with capture');
      });
    });

    group('Stalemate', () {
      test('detects stalemate position', () {
        // Black king trapped, no legal moves, not in check
        final engine = TestChessEngine.fromFEN(
          'k7/2Q5/1K6/8/8/8/8/8 b - - 0 1',
        );
        expect(engine.isStalemate(), isTrue);
        expect(engine.isCheckmate(), isFalse);
        expect(engine.isCheck(), isFalse);
      });

      test('not stalemate when moves available', () {
        final engine = TestChessEngine();
        expect(engine.isStalemate(), isFalse);
      });
    });

    group('Checkmate', () {
      test('detects checkmate - back rank mate', () {
        final engine = TestChessEngine.fromFEN(
          '6k1/5ppp/8/8/8/8/8/R3K3 b - - 0 1', // White rook gives mate
        );
        // First make the mating move
        engine.fromFEN('R5k1/5ppp/8/8/8/8/8/4K3 b - - 0 1');
        expect(engine.isCheckmate(), isTrue);
        expect(engine.isCheck(), isTrue);
      });

      test('detects scholars mate', () {
        // Qxf7# position
        final engine = TestChessEngine.fromFEN(
          'r1bqkb1r/pppp1Qpp/2n2n2/4p3/2B1P3/8/PPPP1PPP/RNB1K1NR b KQkq - 0 1',
        );
        expect(engine.isCheckmate(), isTrue);
      });

      test('not checkmate when can block', () {
        final engine = TestChessEngine.fromFEN(
          'rnb1kbnr/pppp1ppp/8/4p2q/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 0 1',
        );
        expect(engine.isCheckmate(), isFalse);
        expect(engine.isCheck(), isFalse);
      });
    });

    group('Check Detection', () {
      test('detects check from queen', () {
        final engine = TestChessEngine.fromFEN(
          'rnbqkbnr/ppppp1pp/8/5p1Q/4P3/8/PPPP1PPP/RNB1KBNR b KQkq - 0 1',
        );
        expect(engine.isCheck(), isTrue);
      });

      test('detects check from knight', () {
        final engine = TestChessEngine.fromFEN(
          'rnbqkb1r/pppppppp/5N2/8/8/8/PPPPPPPP/RNBQKB1R b KQkq - 0 1',
        );
        expect(engine.isCheck(), isTrue);
      });

      test('no false positive for non-check', () {
        final engine = TestChessEngine();
        expect(engine.isCheck(), isFalse);
      });
    });
  });
}

