import 'package:flutter_test/flutter_test.dart';
import 'package:airo_app/features/games/domain/models/chess_models.dart';

/// Chess models unit tests
void main() {
  group('ChessPiece', () {
    test('creates piece with type and color', () {
      const piece = ChessPiece(type: PieceType.king, color: ChessColor.white);

      expect(piece.type, equals(PieceType.king));
      expect(piece.color, equals(ChessColor.white));
    });

    test('equality works correctly', () {
      const piece1 = ChessPiece(type: PieceType.queen, color: ChessColor.black);
      const piece2 = ChessPiece(type: PieceType.queen, color: ChessColor.black);
      const piece3 = ChessPiece(type: PieceType.queen, color: ChessColor.white);

      expect(piece1, equals(piece2));
      expect(piece1, isNot(equals(piece3)));
    });
  });

  group('ChessSquare', () {
    test('creates square with index', () {
      const square = ChessSquare(27); // d4

      expect(square.index, equals(27));
      expect(square.file, equals(3)); // d
      expect(square.rank, equals(3)); // 4
    });

    test('file and rank calculated correctly from index', () {
      // a1 = index 0, h8 = index 63
      const a1 = ChessSquare(0);
      const h1 = ChessSquare(7);
      const a8 = ChessSquare(56);
      const h8 = ChessSquare(63);

      expect(a1.file, equals(0));
      expect(a1.rank, equals(0));
      expect(h1.file, equals(7));
      expect(h1.rank, equals(0));
      expect(a8.file, equals(0));
      expect(a8.rank, equals(7));
      expect(h8.file, equals(7));
      expect(h8.rank, equals(7));
    });

    test('toAlgebraic returns correct notation', () {
      expect(const ChessSquare(0).toAlgebraic(), equals('a1'));
      expect(const ChessSquare(7).toAlgebraic(), equals('h1'));
      expect(const ChessSquare(56).toAlgebraic(), equals('a8'));
      expect(const ChessSquare(63).toAlgebraic(), equals('h8'));
      expect(const ChessSquare(27).toAlgebraic(), equals('d4'));
    });

    test('equality works correctly', () {
      const s1 = ChessSquare(42);
      const s2 = ChessSquare(42);
      const s3 = ChessSquare(43);

      expect(s1, equals(s2));
      expect(s1, isNot(equals(s3)));
    });
  });

  group('ChessMove', () {
    test('creates move with from and to squares', () {
      const from = ChessSquare(12); // e2
      const to = ChessSquare(28); // e4
      const move = ChessMove(from: from, to: to);

      expect(move.from, equals(from));
      expect(move.to, equals(to));
      expect(move.promotion, isNull);
    });

    test('creates promotion move', () {
      const from = ChessSquare(48); // a7
      const to = ChessSquare(56); // a8
      const move = ChessMove(from: from, to: to, promotion: PieceType.queen);

      expect(move.promotion, equals(PieceType.queen));
    });

    test('equality works correctly', () {
      const from = ChessSquare(1);
      const to = ChessSquare(18);
      const m1 = ChessMove(from: from, to: to);
      const m2 = ChessMove(from: from, to: to);
      const m3 = ChessMove(from: from, to: ChessSquare(19));

      expect(m1, equals(m2));
      expect(m1, isNot(equals(m3)));
    });
  });

  group('ChessBoardState', () {
    test('initial creates standard starting position', () {
      final board = ChessBoardState.initial();

      // Check piece count (16 white + 16 black = 32 pieces)
      final pieceCount = board.squares.where((p) => p != null).length;
      expect(pieceCount, equals(32));

      // Check white pieces on ranks 0-1
      expect(board.squares[0]?.type, equals(PieceType.rook));
      expect(board.squares[0]?.color, equals(ChessColor.white));
      expect(board.squares[4]?.type, equals(PieceType.king));

      // Check black pieces on ranks 6-7
      expect(board.squares[56]?.type, equals(PieceType.rook));
      expect(board.squares[56]?.color, equals(ChessColor.black));
      expect(board.squares[60]?.type, equals(PieceType.king));

      // Check pawns
      for (var i = 8; i < 16; i++) {
        expect(board.squares[i]?.type, equals(PieceType.pawn));
        expect(board.squares[i]?.color, equals(ChessColor.white));
      }
      for (var i = 48; i < 56; i++) {
        expect(board.squares[i]?.type, equals(PieceType.pawn));
        expect(board.squares[i]?.color, equals(ChessColor.black));
      }

      // Check initial state
      expect(board.toMove, equals(ChessColor.white));
      expect(board.whiteCanCastleKingside, isTrue);
      expect(board.whiteCanCastleQueenside, isTrue);
      expect(board.blackCanCastleKingside, isTrue);
      expect(board.blackCanCastleQueenside, isTrue);
      expect(board.enPassantSquare, isNull);
      expect(board.halfmoveClock, equals(0));
      expect(board.fullmoveNumber, equals(1));
      expect(board.moveHistory, isEmpty);
    });

    test('empty squares are null in middle ranks', () {
      final board = ChessBoardState.initial();

      // Ranks 2-5 should be empty (indices 16-47)
      for (var i = 16; i < 48; i++) {
        expect(board.squares[i], isNull, reason: 'Square $i should be empty');
      }
    });
  });

  group('ChessGameState', () {
    test('creates game with initial state', () {
      final game = ChessGameState(
        id: 'game_1',
        board: ChessBoardState.initial(),
        isGameOver: false,
        createdAt: DateTime.now(),
      );

      expect(game.id, equals('game_1'));
      expect(game.isGameOver, isFalse);
      expect(game.result, isNull);
    });

    test('creates completed game', () {
      final game = ChessGameState(
        id: 'game_2',
        board: ChessBoardState.initial(),
        isGameOver: true,
        result: 'white',
        createdAt: DateTime.now(),
        endedAt: DateTime.now(),
      );

      expect(game.isGameOver, isTrue);
      expect(game.result, equals('white'));
      expect(game.endedAt, isNotNull);
    });
  });

  group('MoveClassification', () {
    test('all classifications are distinct', () {
      final classifications = MoveClassification.values;
      expect(
        classifications.length,
        equals(6),
      ); // quiet, capture, check, checkmate, blunder, brilliance
    });
  });
}
