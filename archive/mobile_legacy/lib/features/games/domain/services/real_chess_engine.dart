import 'package:chess/chess.dart' as chess_lib;
import 'package:stockfish/stockfish.dart';
import 'chess_engine.dart';
import '../models/chess_models.dart';

/// Real chess engine using chess.dart and Stockfish
class RealChessEngine with ChessEngineAsync implements ChessEngine {
  late chess_lib.Chess _chess;
  static Stockfish? _stockfishInstance;
  static bool _stockfishReady = false;
  static bool _stockfishInitializing = false;

  RealChessEngine() {
    _chess = chess_lib.Chess();
  }

  Future<void> _ensureStockfishReady() async {
    if (_stockfishReady) {
      print('[CHESS] Stockfish already ready');
      return;
    }

    if (_stockfishInstance == null && !_stockfishInitializing) {
      _stockfishInitializing = true;
      print('[CHESS] Initializing Stockfish...');

      try {
        _stockfishInstance = Stockfish();
        print('[CHESS] Stockfish instance created');

        // Listen for Stockfish ready signal
        _stockfishInstance!.stdout.listen((line) {
          print('[STOCKFISH] $line');
          if (line.contains('uciok')) {
            _stockfishReady = true;
            print('[CHESS] Stockfish ready!');
          }
        });

        // Wait for Stockfish to initialize
        await Future.delayed(const Duration(seconds: 1));

        print('[CHESS] Sending UCI commands...');
        _stockfishInstance!.stdin = 'uci';
        _stockfishInstance!.stdin = 'isready';

        // Wait for ready confirmation
        await Future.delayed(const Duration(milliseconds: 500));

        // Wait for uciok
        int attempts = 0;
        while (!_stockfishReady && attempts < 30) {
          await Future.delayed(const Duration(milliseconds: 100));
          attempts++;
        }

        if (_stockfishReady) {
          print('[CHESS] Stockfish initialization complete');
        } else {
          print(
            '[CHESS] Stockfish initialization timeout after $attempts attempts',
          );
        }
      } finally {
        _stockfishInitializing = false;
      }
    } else if (_stockfishInitializing) {
      print('[CHESS] Waiting for Stockfish initialization to complete...');
      // Wait for initialization to complete
      int attempts = 0;
      while (_stockfishInitializing && attempts < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
      }
      print(
        '[CHESS] Stockfish initialization wait complete (ready=$_stockfishReady)',
      );
    }
  }

  /// Wait for Stockfish to be ready
  @override
  Future<void> waitForReady() async {
    await _ensureStockfishReady();
  }

  Stockfish get _stockfish => _stockfishInstance!;

  @override
  List<ChessMove> getLegalMoves() {
    final moves = _chess.moves({'verbose': true});
    print('[CHESS] getLegalMoves: ${moves.length} moves from chess library');
    if (moves.isNotEmpty) {
      print('[CHESS] First move example: ${moves.first}');
    }
    final converted = moves.map((m) => _convertMove(m)).toList();
    print('[CHESS] Converted to ${converted.length} ChessMove objects');
    return converted;
  }

  @override
  bool makeMove(ChessMove move) {
    final moveStr = _toAlgebraic(move);
    final result = _chess.move(moveStr);
    return result;
  }

  @override
  bool undoMove() {
    final move = _chess.undo_move();
    return move != null;
  }

  @override
  Future<ChessMove?> getBestMove({required ChessDifficulty difficulty}) async {
    // Ensure Stockfish is ready
    await _ensureStockfishReady();

    if (!_stockfishReady || _stockfishInstance == null) {
      // Fallback to random move if Stockfish still not ready
      print('[CHESS] Stockfish not ready, using random move');
      final moves = getLegalMoves();
      if (moves.isEmpty) return null;
      return moves[DateTime.now().millisecond % moves.length];
    }

    // Set Stockfish parameters based on difficulty
    final depth = difficulty.depthLimit;
    final skillLevel = _getSkillLevel(difficulty);

    print(
      '[CHESS] Getting best move with skill level $skillLevel, depth $depth',
    );
    _stockfishInstance!.stdin = 'setoption name Skill Level value $skillLevel';
    _stockfishInstance!.stdin = 'position fen ${_chess.fen}';
    _stockfishInstance!.stdin = 'go depth $depth';

    // Wait for bestmove response
    String? bestMoveStr;
    await for (final line in _stockfishInstance!.stdout) {
      if (line.startsWith('bestmove')) {
        bestMoveStr = line.split(' ')[1];
        break;
      }
    }

    if (bestMoveStr == null || bestMoveStr == '(none)') {
      print('[CHESS] No best move found');
      return null;
    }

    print('[CHESS] Best move: $bestMoveStr');
    // Convert UCI move to ChessMove
    return _fromUCI(bestMoveStr);
  }

  int _getSkillLevel(ChessDifficulty difficulty) {
    return switch (difficulty) {
      ChessDifficulty.easy => 5, // Skill level 0-20, 5 is beginner
      ChessDifficulty.medium => 10, // Intermediate
      ChessDifficulty.hard => 15, // Advanced
      ChessDifficulty.expert => 20, // Maximum strength (World Champion)
    };
  }

  @override
  int evaluatePosition() {
    // Simple material count evaluation
    // Stockfish evaluation would require parsing 'go' output
    int score = 0;
    final board = _chess.board;

    for (var piece in board) {
      if (piece == null) continue;
      final value = _getPieceValue(piece.type);
      score += piece.color == chess_lib.Color.WHITE ? value : -value;
    }

    return score;
  }

  int _getPieceValue(chess_lib.PieceType type) {
    return switch (type) {
      chess_lib.PieceType.PAWN => 100,
      chess_lib.PieceType.KNIGHT => 320,
      chess_lib.PieceType.BISHOP => 330,
      chess_lib.PieceType.ROOK => 500,
      chess_lib.PieceType.QUEEN => 900,
      chess_lib.PieceType.KING => 20000,
      _ => 0, // Default fallback
    };
  }

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

    // chess.dart uses 0x88 board representation (128 squares)
    // 0x88 layout: 0x00-0x07 = a8-h8, 0x10-0x17 = a7-h7, ..., 0x70-0x77 = a1-h1
    // Our layout: 0-7 = a1-h1, 8-15 = a2-h2, ..., 56-63 = a8-h8
    // So we need to flip the rank: our_rank = 7 - 0x88_rank
    for (int i = 0; i < board.length; i++) {
      final piece = board[i];
      if (piece != null) {
        // Convert 0x88 index to 64-square index
        final rank0x88 = i ~/ 16; // 0 = rank 8, 7 = rank 1
        final file = i % 16;
        if (file < 8) {
          // Valid square in 0x88 representation
          // Convert to our indexing: rank 1 = row 0, rank 8 = row 7
          final ourRank = 7 - rank0x88;
          final index = ourRank * 8 + file;
          if (index >= 0 && index < 64) {
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
      enPassantSquare: null, // TODO: Parse from FEN
      halfmoveClock: 0, // TODO: Parse from FEN
      fullmoveNumber: 1, // TODO: Parse from FEN
      moveHistory: [], // TODO: Track move history
    );
  }

  @override
  void reset() {
    _chess.reset();
  }

  @override
  String toFEN() => _chess.fen;

  @override
  void fromFEN(String fen) {
    _chess.load(fen);
  }

  // Helper methods for conversion

  ChessMove _convertMove(dynamic move) {
    final fromStr = move['from'] as String;
    final toStr = move['to'] as String;
    final from = _squareToIndex(fromStr);
    final to = _squareToIndex(toStr);
    final promotion = move['promotion'] != null
        ? _convertPieceTypeFromString(move['promotion'] as String)
        : null;

    final chessMove = ChessMove(
      from: ChessSquare(from),
      to: ChessSquare(to),
      promotion: promotion,
    );

    // Debug: log first few conversions
    if (from < 16) {
      // Only log moves from first two ranks
      print('[CHESS] Converted move: $fromStr($from) -> $toStr($to)');
    }

    return chessMove;
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
    final promotion = move.promotion != null
        ? _pieceTypeToChar(move.promotion!)
        : '';
    return '$from$to$promotion';
  }

  ChessMove? _fromUCI(String uci) {
    if (uci.length < 4) return null;

    final from = _squareToIndex(uci.substring(0, 2));
    final to = _squareToIndex(uci.substring(2, 4));
    final promotion = uci.length > 4
        ? _convertPieceTypeFromString(uci[4])
        : null;

    return ChessMove(
      from: ChessSquare(from),
      to: ChessSquare(to),
      promotion: promotion,
    );
  }

  PieceType _convertPieceTypeFromString(String type) {
    switch (type.toLowerCase()) {
      case 'p':
        return PieceType.pawn;
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
      _ => PieceType.pawn, // Default fallback
    };
  }

  String _pieceTypeToChar(PieceType type) {
    switch (type) {
      case PieceType.pawn:
        return 'p';
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
    }
  }

  void dispose() {
    _stockfish.stdin = 'quit';
  }
}
