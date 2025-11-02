import 'package:equatable/equatable.dart';

/// Chess piece types
enum PieceType { pawn, knight, bishop, rook, queen, king }

/// Chess colors
enum ChessColor { white, black }

/// Chess piece
class ChessPiece extends Equatable {
  final PieceType type;
  final ChessColor color;

  const ChessPiece({required this.type, required this.color});

  @override
  List<Object?> get props => [type, color];
}

/// Chess square position (0-63, rank-file notation)
class ChessSquare extends Equatable {
  final int index; // 0-63

  const ChessSquare(this.index);

  /// Get file (column) 0-7
  int get file => index % 8;

  /// Get rank (row) 0-7
  int get rank => index ~/ 8;

  /// Convert to algebraic notation (a1-h8)
  String toAlgebraic() {
    final file = String.fromCharCode(97 + this.file); // a-h
    final rank = (this.rank + 1).toString(); // 1-8
    return '$file$rank';
  }

  @override
  List<Object?> get props => [index];
}

/// Chess move
class ChessMove extends Equatable {
  final ChessSquare from;
  final ChessSquare to;
  final PieceType? promotion; // For pawn promotion

  const ChessMove({
    required this.from,
    required this.to,
    this.promotion,
  });

  @override
  List<Object?> get props => [from, to, promotion];
}

/// Move classification for audio events
enum MoveClassification {
  quiet,
  capture,
  check,
  checkmate,
  blunder,
  brilliance,
}

/// Chess board state
class ChessBoardState extends Equatable {
  final List<ChessPiece?> squares; // 64 squares
  final ChessColor toMove;
  final bool whiteCanCastleKingside;
  final bool whiteCanCastleQueenside;
  final bool blackCanCastleKingside;
  final bool blackCanCastleQueenside;
  final ChessSquare? enPassantSquare;
  final int halfmoveClock;
  final int fullmoveNumber;
  final List<ChessMove> moveHistory;

  const ChessBoardState({
    required this.squares,
    required this.toMove,
    required this.whiteCanCastleKingside,
    required this.whiteCanCastleQueenside,
    required this.blackCanCastleKingside,
    required this.blackCanCastleQueenside,
    this.enPassantSquare,
    required this.halfmoveClock,
    required this.fullmoveNumber,
    required this.moveHistory,
  });

  /// Create initial board state
  static ChessBoardState initial() {
    final squares = List<ChessPiece?>.filled(64, null);

    // Set up white pieces (rank 0-1)
    squares[0] = const ChessPiece(type: PieceType.rook, color: ChessColor.white);
    squares[1] = const ChessPiece(type: PieceType.knight, color: ChessColor.white);
    squares[2] = const ChessPiece(type: PieceType.bishop, color: ChessColor.white);
    squares[3] = const ChessPiece(type: PieceType.queen, color: ChessColor.white);
    squares[4] = const ChessPiece(type: PieceType.king, color: ChessColor.white);
    squares[5] = const ChessPiece(type: PieceType.bishop, color: ChessColor.white);
    squares[6] = const ChessPiece(type: PieceType.knight, color: ChessColor.white);
    squares[7] = const ChessPiece(type: PieceType.rook, color: ChessColor.white);

    for (int i = 8; i < 16; i++) {
      squares[i] = const ChessPiece(type: PieceType.pawn, color: ChessColor.white);
    }

    // Set up black pieces (rank 6-7)
    for (int i = 48; i < 56; i++) {
      squares[i] = const ChessPiece(type: PieceType.pawn, color: ChessColor.black);
    }

    squares[56] = const ChessPiece(type: PieceType.rook, color: ChessColor.black);
    squares[57] = const ChessPiece(type: PieceType.knight, color: ChessColor.black);
    squares[58] = const ChessPiece(type: PieceType.bishop, color: ChessColor.black);
    squares[59] = const ChessPiece(type: PieceType.queen, color: ChessColor.black);
    squares[60] = const ChessPiece(type: PieceType.king, color: ChessColor.black);
    squares[61] = const ChessPiece(type: PieceType.bishop, color: ChessColor.black);
    squares[62] = const ChessPiece(type: PieceType.knight, color: ChessColor.black);
    squares[63] = const ChessPiece(type: PieceType.rook, color: ChessColor.black);

    return ChessBoardState(
      squares: squares,
      toMove: ChessColor.white,
      whiteCanCastleKingside: true,
      whiteCanCastleQueenside: true,
      blackCanCastleKingside: true,
      blackCanCastleQueenside: true,
      enPassantSquare: null,
      halfmoveClock: 0,
      fullmoveNumber: 1,
      moveHistory: [],
    );
  }

  @override
  List<Object?> get props => [
        squares,
        toMove,
        whiteCanCastleKingside,
        whiteCanCastleQueenside,
        blackCanCastleKingside,
        blackCanCastleQueenside,
        enPassantSquare,
        halfmoveClock,
        fullmoveNumber,
        moveHistory,
      ];
}

/// Chess game state
class ChessGameState extends Equatable {
  final String id;
  final ChessBoardState board;
  final bool isGameOver;
  final String? result; // 'white', 'black', 'draw'
  final DateTime createdAt;
  final DateTime? endedAt;

  const ChessGameState({
    required this.id,
    required this.board,
    required this.isGameOver,
    this.result,
    required this.createdAt,
    this.endedAt,
  });

  @override
  List<Object?> get props => [
        id,
        board,
        isGameOver,
        result,
        createdAt,
        endedAt,
      ];
}

