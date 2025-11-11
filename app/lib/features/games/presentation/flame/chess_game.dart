import 'package:flame/game.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import '../../domain/models/chess_models.dart';
import '../../domain/services/chess_engine.dart';
import '../../domain/services/real_chess_engine.dart';
import '../../domain/services/chess_audio_manager.dart';
import '../../domain/services/chess_tts_manager.dart';
import '../../domain/services/move_event_dispatcher.dart';

/// Flame-based chess game
class ChessGameFlame extends FlameGame with TapCallbacks {
  late ChessEngine engine;
  late ChessAudioManager audioManager;
  late ChessTTSManager ttsManager;
  late MoveEventDispatcher dispatcher;
  late ChessDifficulty difficulty;

  // Player color (randomly assigned)
  late ChessColor playerColor;
  late ChessColor aiColor;

  ChessSquare? selectedSquare;
  List<ChessMove> legalMoves = [];
  bool isPlayerTurn = true;
  bool isGameOver = false;
  ChessMove? lastMove;
  String gameStatus = '';

  // Speech bubble state
  String? currentSpeechBubble;
  int? speakingPieceIndex;
  DateTime? speechBubbleStartTime;

  // Board rendering
  late Paint lightSquarePaint;
  late Paint darkSquarePaint;
  late Paint selectedSquarePaint;
  late Paint legalMovePaint;
  late Paint lastMovePaint;
  late Paint checkPaint;

  late double squareSize;
  late Offset boardOffset;

  ChessGameFlame({required this.difficulty}) : super();

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Player is always white (white moves first in chess)
    playerColor = ChessColor.white;
    aiColor = ChessColor.black;

    print(
      '[CHESS] Player is ${playerColor.name.toUpperCase()}, AI is ${aiColor.name.toUpperCase()}',
    );

    // Initialize engine and audio
    engine = RealChessEngine();

    // Wait for Stockfish to be ready
    await (engine as RealChessEngine).waitForReady();

    audioManager = FakeChessAudioManager();
    ttsManager = ChessTTSManager();
    dispatcher = MoveEventDispatcher();

    // Setup paints
    lightSquarePaint = Paint()..color = const Color(0xFFEDD5B1);
    darkSquarePaint = Paint()..color = const Color(0xFFA0826D);
    selectedSquarePaint = Paint()..color = const Color(0xFFBECA50);
    legalMovePaint = Paint()
      ..color = const Color(0xFF7FC97F).withValues(alpha: 0.5);
    lastMovePaint = Paint()
      ..color = const Color(0xFFCDD26A).withValues(alpha: 0.4);
    checkPaint = Paint()
      ..color = const Color(0xFFFF6B6B).withValues(alpha: 0.6);

    // Calculate board size
    squareSize = size.x / 8;
    boardOffset = Offset(0, size.y * 0.1);

    // Initialize TTS
    await ttsManager.initialize();

    // Play background music
    await audioManager.playBackgroundMusic(engine.getBoardState());

    // Player is always white, so player moves first
    // No need to trigger AI move here
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (!isPlayerTurn || isGameOver) {
      print(
        '[CHESS] Tap ignored: isPlayerTurn=$isPlayerTurn, isGameOver=$isGameOver',
      );
      return;
    }

    final board = engine.getBoardState();
    final tapPosition = event.localPosition;

    // Check if tap is on board
    if (tapPosition.y < boardOffset.dy ||
        tapPosition.y > boardOffset.dy + squareSize * 8 ||
        tapPosition.x < 0 ||
        tapPosition.x > squareSize * 8) {
      print('[CHESS] Tap outside board');
      return;
    }

    final col = (tapPosition.x / squareSize).floor();
    final displayRow = ((tapPosition.y - boardOffset.dy) / squareSize).floor();

    // Convert display row back to actual board row based on player's perspective
    // If player is white, flip board (white at bottom)
    // If player is black, don't flip (black at bottom)
    final row = playerColor == ChessColor.white ? 7 - displayRow : displayRow;
    final index = row * 8 + col;

    print('[CHESS] Tap at col=$col, row=$row, index=$index');

    if (index < 0 || index >= 64) return;

    final piece = board.squares[index];

    if (selectedSquare == null) {
      // Select piece - only allow player's pieces
      if (piece != null && piece.color == playerColor && isPlayerTurn) {
        selectedSquare = ChessSquare(index);
        final allMoves = engine.getLegalMoves();
        print(
          '[CHESS] All moves: ${allMoves.map((m) => '${m.from.index}->${m.to.index}').join(', ')}',
        );
        legalMoves = allMoves
            .where((move) => move.from.index == index)
            .toList();
        print(
          '[CHESS] Selected piece at $index, ${legalMoves.length} legal moves',
        );
      }
    } else {
      // Try to move
      final move = ChessMove(from: selectedSquare!, to: ChessSquare(index));
      print('[CHESS] Attempting move from ${selectedSquare!.index} to $index');
      print(
        '[CHESS] Legal moves: ${legalMoves.map((m) => '${m.from.index}->${m.to.index}').join(', ')}',
      );

      if (legalMoves.contains(move)) {
        print('[CHESS] Move is legal, executing');
        _makePlayerMove(move);
      } else {
        print('[CHESS] Move not legal');
        // Deselect or select new piece
        if (piece != null && piece.color == playerColor && isPlayerTurn) {
          selectedSquare = ChessSquare(index);
          legalMoves = engine
              .getLegalMoves()
              .where((move) => move.from.index == index)
              .toList();
          print(
            '[CHESS] Selected new piece at $index, ${legalMoves.length} legal moves',
          );
        } else {
          selectedSquare = null;
          legalMoves = [];
          print('[CHESS] Deselected');
        }
      }
    }
  }

  void _makePlayerMove(ChessMove move) async {
    await _executeMove(move, isPlayerMove: true);

    selectedSquare = null;
    legalMoves = [];

    // Check game over
    if (engine.isCheckmate()) {
      isGameOver = true;
      gameStatus = 'Checkmate! You win!';
      return;
    }
    if (engine.isStalemate()) {
      isGameOver = true;
      gameStatus = 'Stalemate! Draw.';
      return;
    }

    // AI move
    await _makeAIMove();
  }

  Future<void> _makeAIMove() async {
    isPlayerTurn = false;

    // Show "AI is thinking..." status
    gameStatus = 'AI is thinking...';

    // Add delay based on difficulty (harder = longer thinking time)
    final thinkingDelay = switch (difficulty) {
      ChessDifficulty.easy => const Duration(milliseconds: 800),
      ChessDifficulty.medium => const Duration(milliseconds: 1200),
      ChessDifficulty.hard => const Duration(milliseconds: 1800),
      ChessDifficulty.expert => const Duration(milliseconds: 2500),
    };

    await Future.delayed(thinkingDelay);

    final aiMove = await engine.getBestMove(difficulty: difficulty);
    if (aiMove != null) {
      await _executeMove(aiMove, isPlayerMove: false);

      // Check game over after AI move
      if (engine.isCheckmate()) {
        isGameOver = true;
        gameStatus = 'Checkmate! AI wins!';
      } else if (engine.isStalemate()) {
        isGameOver = true;
        gameStatus = 'Stalemate! Draw.';
      }
    }

    isPlayerTurn = true;
  }

  Future<void> _executeMove(
    ChessMove move, {
    required bool isPlayerMove,
  }) async {
    final boardBefore = engine.getBoardState();
    final movedPiece = boardBefore.squares[move.from.index]!;
    final isCapture = boardBefore.squares[move.to.index] != null;

    engine.makeMove(move);
    lastMove = move;

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

    // Play audio with DotA-like responses
    await _playMoveAudio(event, isPlayerMove: isPlayerMove);

    // Update game status
    if (engine.isCheck()) {
      gameStatus = 'Check!';
    } else {
      gameStatus = '';
    }
  }

  Future<void> _playMoveAudio(
    MoveEvent event, {
    required bool isPlayerMove,
  }) async {
    try {
      // Use TTS to speak the DotA-style voice line in real-time!
      final voiceLine = await ttsManager.playMoveVoice(
        event,
        isPlayerMove: isPlayerMove,
      );

      // Show speech bubble
      currentSpeechBubble = voiceLine;
      speakingPieceIndex = event.move.to.index; // The piece that just moved
      speechBubbleStartTime = DateTime.now();

      // Hide speech bubble after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (speechBubbleStartTime != null &&
            DateTime.now().difference(speechBubbleStartTime!).inSeconds >= 3) {
          currentSpeechBubble = null;
          speakingPieceIndex = null;
          speechBubbleStartTime = null;
        }
      });
    } catch (e) {
      print('[CHESS] Error playing TTS: $e');
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    _drawBoard(canvas);
    _drawCoordinates(canvas);
    _drawPieces(canvas);
    _drawSpeechBubble(canvas);
    _drawGameStatus(canvas);
  }

  void _drawBoard(Canvas canvas) {
    final board = engine.getBoardState();

    for (int row = 0; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        // Flip the board based on player's perspective
        // If player is white, flip board (white at bottom)
        // If player is black, don't flip (black at bottom)
        final displayRow = playerColor == ChessColor.white ? 7 - row : row;
        final index = row * 8 + col;

        // Chess board: a1 (bottom-left for white) is dark square
        // Standard chess board has dark square on bottom-left (a1)
        // row 0 = rank 8, row 7 = rank 1
        // col 0 = file a, col 7 = file h
        // For standard chess coloring: (row + col) % 2 == 1 means light square
        final isLight = (row + col) % 2 == 1;
        final paint = isLight ? lightSquarePaint : darkSquarePaint;

        final rect = Rect.fromLTWH(
          col * squareSize,
          boardOffset.dy + displayRow * squareSize,
          squareSize,
          squareSize,
        );

        canvas.drawRect(rect, paint);

        // Highlight last move
        if (lastMove != null) {
          if (lastMove!.from.index == index || lastMove!.to.index == index) {
            canvas.drawRect(rect, lastMovePaint);
          }
        }

        // Highlight selected square
        if (selectedSquare?.index == index) {
          canvas.drawRect(rect, selectedSquarePaint);
        }

        // Highlight legal moves
        if (legalMoves.any((m) => m.to.index == index)) {
          canvas.drawCircle(rect.center, squareSize * 0.15, legalMovePaint);
        }

        // Highlight king in check
        if (engine.isCheck()) {
          final piece = board.squares[index];
          if (piece != null &&
              piece.type == PieceType.king &&
              piece.color == board.toMove) {
            canvas.drawRect(rect, checkPaint);
          }
        }
      }
    }
  }

  void _drawCoordinates(Canvas canvas) {
    // Draw file labels (a-h) at bottom
    for (int col = 0; col < 8; col++) {
      final file = String.fromCharCode(97 + col); // a-h
      final textPainter = TextPainter(
        text: TextSpan(
          text: file,
          style: TextStyle(
            color: (col % 2 == 0)
                ? darkSquarePaint.color
                : lightSquarePaint.color,
            fontSize: squareSize * 0.2,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          col * squareSize + squareSize - textPainter.width - 4,
          boardOffset.dy + 7 * squareSize + squareSize - textPainter.height - 2,
        ),
      );
    }

    // Draw rank labels (1-8) on left
    for (int row = 0; row < 8; row++) {
      final rank = (8 - row).toString(); // 8-1 (top to bottom)
      final textPainter = TextPainter(
        text: TextSpan(
          text: rank,
          style: TextStyle(
            color: (row % 2 == 0)
                ? lightSquarePaint.color
                : darkSquarePaint.color,
            fontSize: squareSize * 0.2,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(4, boardOffset.dy + row * squareSize + 2),
      );
    }
  }

  void _drawGameStatus(Canvas canvas) {
    if (gameStatus.isEmpty && !isGameOver) return;

    final statusText = isGameOver ? gameStatus : gameStatus;
    final textPainter = TextPainter(
      text: TextSpan(
        text: statusText,
        style: TextStyle(
          color: isGameOver ? Colors.red : Colors.orange,
          fontSize: 24,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.8),
              offset: const Offset(2, 2),
              blurRadius: 4,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        size.x / 2 - textPainter.width / 2,
        boardOffset.dy / 2 - textPainter.height / 2,
      ),
    );
  }

  void _drawPieces(Canvas canvas) {
    final board = engine.getBoardState();

    // White pieces (outlined/hollow) and Black pieces (filled/solid)
    const whitePieceSymbols = {
      PieceType.king: '♔',
      PieceType.queen: '♕',
      PieceType.rook: '♖',
      PieceType.bishop: '♗',
      PieceType.knight: '♘',
      PieceType.pawn: '♙',
    };

    const blackPieceSymbols = {
      PieceType.king: '♚',
      PieceType.queen: '♛',
      PieceType.rook: '♜',
      PieceType.bishop: '♝',
      PieceType.knight: '♞',
      PieceType.pawn: '♟',
    };

    for (int i = 0; i < 64; i++) {
      final piece = board.squares[i];
      if (piece == null) continue;

      final row = i ~/ 8;
      final col = i % 8;
      // Flip the board based on player's perspective
      // If player is white, flip board (white at bottom)
      // If player is black, don't flip (black at bottom)
      final displayRow = playerColor == ChessColor.white ? 7 - row : row;

      // Get the correct symbol based on piece color
      final symbol = piece.color == ChessColor.white
          ? whitePieceSymbols[piece.type]
          : blackPieceSymbols[piece.type];

      final textPainter = TextPainter(
        text: TextSpan(
          text: symbol ?? '?',
          style: TextStyle(
            // Use contrasting colors for visibility on both light and dark squares
            color: piece.color == ChessColor.white
                ? const Color(0xFFF0F0F0) // Light gray for white pieces
                : const Color(0xFF1A1A1A), // Dark gray/black for black pieces
            fontSize: squareSize * 0.6,
            fontWeight: FontWeight.bold,
            shadows: [
              // Add shadow for better visibility
              Shadow(
                color: piece.color == ChessColor.white
                    ? Colors.black.withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.3),
                offset: const Offset(1, 1),
                blurRadius: 2,
              ),
            ],
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
              displayRow * squareSize +
              squareSize / 2 -
              textPainter.height / 2,
        ),
      );
    }
  }

  void _drawSpeechBubble(Canvas canvas) {
    if (currentSpeechBubble == null || speakingPieceIndex == null) return;

    final row = speakingPieceIndex! ~/ 8;
    final col = speakingPieceIndex! % 8;

    // Calculate display position based on player's perspective
    final displayRow = playerColor == ChessColor.white ? 7 - row : row;

    // Position bubble above the piece
    final pieceX = col * squareSize + squareSize / 2;
    final pieceY = boardOffset.dy + displayRow * squareSize;

    // Create text painter for the speech
    final textPainter = TextPainter(
      text: TextSpan(
        text: currentSpeechBubble,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 3,
    );
    textPainter.layout(maxWidth: squareSize * 3);

    // Calculate bubble dimensions
    const padding = 8.0;
    final bubbleWidth = textPainter.width + padding * 2;
    final bubbleHeight = textPainter.height + padding * 2;

    // Position bubble above piece (centered horizontally)
    final bubbleX = pieceX - bubbleWidth / 2;
    final bubbleY = pieceY - bubbleHeight - 20; // 20px above piece

    // Draw bubble background (rounded rectangle)
    final bubbleRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(bubbleX, bubbleY, bubbleWidth, bubbleHeight),
      const Radius.circular(8),
    );

    final bubblePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawRRect(bubbleRect, bubblePaint);
    canvas.drawRRect(bubbleRect, borderPaint);

    // Draw speech bubble tail (triangle pointing to piece)
    final tailPath = Path();
    final tailTipX = pieceX;
    final tailTipY = pieceY - 5;
    final tailLeftX = pieceX - 8;
    final tailLeftY = bubbleY + bubbleHeight;
    final tailRightX = pieceX + 8;
    final tailRightY = bubbleY + bubbleHeight;

    tailPath.moveTo(tailTipX, tailTipY);
    tailPath.lineTo(tailLeftX, tailLeftY);
    tailPath.lineTo(tailRightX, tailRightY);
    tailPath.close();

    canvas.drawPath(tailPath, bubblePaint);
    canvas.drawPath(tailPath, borderPaint);

    // Draw text
    textPainter.paint(canvas, Offset(bubbleX + padding, bubbleY + padding));
  }

  @override
  Future<void> onRemove() async {
    try {
      await audioManager.dispose();
    } catch (e) {
      // audioManager may not be initialized if onLoad failed
    }
    try {
      await ttsManager.dispose();
    } catch (e) {
      // ttsManager may not be initialized if onLoad failed
    }
    try {
      dispatcher.dispose();
    } catch (e) {
      // dispatcher may not be initialized if onLoad failed
    }
  }
}
