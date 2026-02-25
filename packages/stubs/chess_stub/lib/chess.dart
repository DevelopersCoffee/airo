/// Stub implementation of chess package for TV builds

/// Chess color enum
class Color {
  static const Color WHITE = Color._('w');
  static const Color BLACK = Color._('b');
  
  final String _value;
  const Color._(this._value);
  
  @override
  String toString() => _value;
}

/// Piece type enum
class PieceType {
  static const PieceType PAWN = PieceType._('p');
  static const PieceType KNIGHT = PieceType._('n');
  static const PieceType BISHOP = PieceType._('b');
  static const PieceType ROOK = PieceType._('r');
  static const PieceType QUEEN = PieceType._('q');
  static const PieceType KING = PieceType._('k');
  
  final String _value;
  const PieceType._(this._value);
  
  @override
  String toString() => _value;
}

/// Piece class
class Piece {
  final PieceType type;
  final Color color;
  
  const Piece(this.type, this.color);
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

