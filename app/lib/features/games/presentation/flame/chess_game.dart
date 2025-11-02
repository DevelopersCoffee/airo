import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';
import '../../domain/models/chess_models.dart';
import '../../domain/services/chess_engine.dart';
import '../../domain/services/chess_audio_manager.dart';
import '../../domain/services/move_event_dispatcher.dart';

/// Flame-based chess game
class ChessGameFlame extends FlameGame {
  late ChessEngine engine;
  late ChessAudioManager audioManager;
  late MoveEventDispatcher dispatcher;
  late ChessDifficulty difficulty;

  ChessSquare? selectedSquare;
  List<ChessMove> legalMoves = [];
  bool isPlayerTurn = true;
  bool isGameOver = false;

  // Board rendering
  late Paint lightSquarePaint;
  late Paint darkSquarePaint;
  late Paint selectedSquarePaint;
  late Paint legalMovePaint;

  late double squareSize;
  late Offset boardOffset;

  ChessGameFlame({required this.difficulty}) : super();

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Initialize engine and audio
    engine = FakeChessEngine();
    audioManager = FakeChessAudioManager();
    dispatcher = MoveEventDispatcher();

    // Setup paints
    lightSquarePaint = Paint()..color = const Color(0xFFEDD5B1);
    darkSquarePaint = Paint()..color = const Color(0xFFA0826D);
    selectedSquarePaint = Paint()..color = const Color(0xFFBECA50);
    legalMovePaint = Paint()
      ..color = const Color(0xFF7FC97F).withValues(alpha: 0.5);

    // Calculate board size
    squareSize = size.x / 8;
    boardOffset = Offset(0, size.y * 0.1);

    // Load audio
    await _loadAudio();

    // Play background music
    await audioManager.playBackgroundMusic(engine.getBoardState());
  }

  Future<void> _loadAudio() async {
    try {
      // Load piece voice lines
      for (final piece in [
        'pawn',
        'knight',
        'bishop',
        'rook',
        'queen',
        'king',
      ]) {
        for (final event in ['quiet', 'capture', 'check', 'checkmate']) {
          try {
            await FlameAudio.audioCache.load('audio/pieces/$piece/$event.mp3');
          } catch (e) {
            print('Could not load audio: audio/pieces/$piece/$event.mp3');
          }
        }
      }

      // Load stingers
      try {
        await FlameAudio.audioCache.load('audio/stingers/capture.mp3');
      } catch (_) {
        // Ignore audio loading errors
      }
      try {
        await FlameAudio.audioCache.load('audio/stingers/check.mp3');
      } catch (_) {
        // Ignore audio loading errors
      }
      try {
        await FlameAudio.audioCache.load('audio/stingers/checkmate.mp3');
      } catch (_) {
        // Ignore audio loading errors
      }

      // Load background music
      try {
        await FlameAudio.audioCache.load('audio/music/opening.mp3');
      } catch (_) {
        // Ignore audio loading errors
      }
      try {
        await FlameAudio.audioCache.load('audio/music/midgame.mp3');
      } catch (_) {
        // Ignore audio loading errors
      }
      try {
        await FlameAudio.audioCache.load('audio/music/endgame.mp3');
      } catch (_) {
        // Ignore audio loading errors
      }
    } catch (e) {
      print('Error loading audio: $e');
    }
  }

  void onTapDown(TapDownEvent event) {
    final board = engine.getBoardState();
    final tapPosition = event.localPosition;

    // Check if tap is on board
    if (tapPosition.y < boardOffset.dy ||
        tapPosition.y > boardOffset.dy + squareSize * 8 ||
        tapPosition.x < 0 ||
        tapPosition.x > squareSize * 8) {
      return;
    }

    final col = (tapPosition.x / squareSize).floor();
    final row = ((tapPosition.y - boardOffset.dy) / squareSize).floor();
    final index = row * 8 + col;

    if (index < 0 || index >= 64) return;

    final piece = board.squares[index];

    if (selectedSquare == null) {
      // Select piece
      if (piece != null && piece.color == board.toMove && isPlayerTurn) {
        selectedSquare = ChessSquare(index);
        legalMoves = engine
            .getLegalMoves()
            .where((move) => move.from.index == index)
            .toList();
      }
    } else {
      // Try to move
      final move = ChessMove(from: selectedSquare!, to: ChessSquare(index));
      if (legalMoves.contains(move)) {
        _makeMove(move);
      } else {
        // Deselect or select new piece
        if (piece != null && piece.color == board.toMove && isPlayerTurn) {
          selectedSquare = ChessSquare(index);
          legalMoves = engine
              .getLegalMoves()
              .where((move) => move.from.index == index)
              .toList();
        } else {
          selectedSquare = null;
          legalMoves = [];
        }
      }
    }
  }

  void _makeMove(ChessMove move) async {
    final boardBefore = engine.getBoardState();
    final movedPiece = boardBefore.squares[move.from.index]!;
    final isCapture = boardBefore.squares[move.to.index] != null;

    engine.makeMove(move);

    // Create and dispatch move event
    final event = MoveEventDispatcher.createMoveEvent(
      move: move,
      piece: movedPiece.type,
      boardBefore: boardBefore,
      boardAfter: engine.getBoardState(),
      isCapture: isCapture,
      isCheck: engine.isCheck(),
      isCheckmate: engine.isCheckmate(),
      evaluation: engine.evaluatePosition(),
    );

    // Play audio
    await _playMoveAudio(event);

    selectedSquare = null;
    legalMoves = [];

    // Check game over
    if (engine.isCheckmate() || engine.isStalemate()) {
      isGameOver = true;
      return;
    }

    // AI move
    isPlayerTurn = false;
    await Future.delayed(const Duration(milliseconds: 500));

    final aiMove = await engine.getBestMove(difficulty: difficulty);
    if (aiMove != null) {
      _makeMove(aiMove);
    }

    isPlayerTurn = true;
  }

  Future<void> _playMoveAudio(MoveEvent event) async {
    try {
      final pieceName = event.piece.name;
      final eventName = event.classification.name;

      // Play voice line
      await FlameAudio.play(
        'audio/pieces/$pieceName/$eventName.mp3',
        volume: 0.8,
      );

      // Play stinger if needed
      if (event.isCapture) {
        await FlameAudio.play('audio/stingers/capture.mp3', volume: 0.6);
      }
      if (event.isCheck) {
        await FlameAudio.play('audio/stingers/check.mp3', volume: 0.6);
      }
      if (event.isCheckmate) {
        await FlameAudio.play('audio/stingers/checkmate.mp3', volume: 0.8);
      }
    } catch (e) {
      print('Error playing audio: $e');
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    _drawBoard(canvas);
    _drawPieces(canvas);
  }

  void _drawBoard(Canvas canvas) {
    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        final index = row * 8 + col;
        final isLight = (row + col) % 2 == 0;
        final paint = isLight ? lightSquarePaint : darkSquarePaint;

        final rect = Rect.fromLTWH(
          col * squareSize,
          boardOffset.dy + row * squareSize,
          squareSize,
          squareSize,
        );

        canvas.drawRect(rect, paint);

        // Highlight selected square
        if (selectedSquare?.index == index) {
          canvas.drawRect(rect, selectedSquarePaint);
        }

        // Highlight legal moves
        if (legalMoves.any((m) => m.to.index == index)) {
          canvas.drawCircle(rect.center, squareSize * 0.15, legalMovePaint);
        }
      }
    }
  }

  void _drawPieces(Canvas canvas) {
    final board = engine.getBoardState();
    const pieceSymbols = {
      PieceType.pawn: '♟',
      PieceType.knight: '♞',
      PieceType.bishop: '♝',
      PieceType.rook: '♜',
      PieceType.queen: '♛',
      PieceType.king: '♚',
    };

    for (int i = 0; i < 64; i++) {
      final piece = board.squares[i];
      if (piece == null) continue;

      final row = i ~/ 8;
      final col = i % 8;
      final symbol = pieceSymbols[piece.type] ?? '?';
      final displaySymbol = piece.color == ChessColor.white
          ? symbol.toUpperCase()
          : symbol;

      final textPainter = TextPainter(
        text: TextSpan(
          text: displaySymbol,
          style: TextStyle(
            color: piece.color == ChessColor.white
                ? Colors.white
                : Colors.black,
            fontSize: squareSize * 0.6,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          col * squareSize + squareSize / 2 - textPainter.width / 2,
          boardOffset.dy +
              row * squareSize +
              squareSize / 2 -
              textPainter.height / 2,
        ),
      );
    }
  }

  @override
  Future<void> onRemove() async {
    await audioManager.dispose();
    dispatcher.dispose();
  }
}
