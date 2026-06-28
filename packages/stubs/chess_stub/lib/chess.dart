/// Stub implementation of chess package for TV builds

/// Chess color enum
enum Color {
  WHITE._('w'),
  BLACK._('b');

  const Color._(this._value);
  final String _value;

  @override
  String toString() => _value;
}

/// Piece type enum
enum PieceType {
  PAWN._('p'),
  KNIGHT._('n'),
  BISHOP._('b'),
  ROOK._('r'),
  QUEEN._('q'),
  KING._('k');

  const PieceType._(this._value);
  final String _value;

  @override
  String toString() => _value;
}

/// Piece class
class Piece {
  const Piece(this.type, this.color);
  final PieceType type;
  final Color color;
}

/// Stub Chess class
class Chess {
  /// Current FEN position
  String get fen => 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  /// Current turn
  Color get turn => Color.WHITE;

  /// Board state (128 squares for 0x88 representation)
  List<Piece?> get board => List.filled(128, null);

  /// Check if in checkmate
  bool get in_checkmate => false;

  /// Check if in check
  bool get in_check => false;

  /// Check if in stalemate
  bool get in_stalemate => false;

  /// Get legal moves
  List<Map<String, dynamic>> moves([Map<String, dynamic>? options]) => [];

  /// Make a move
  bool move(dynamic move) => false;

  /// Undo last move
  Map<String, dynamic>? undo_move() => null;

  /// Load FEN position
  bool load(String fen) => false;

  /// Reset to starting position
  void reset() {}
}
