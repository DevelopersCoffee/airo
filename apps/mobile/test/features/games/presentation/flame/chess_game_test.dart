import 'package:airo_app/features/games/domain/models/chess_models.dart';
import 'package:airo_app/features/games/domain/services/chess_audio_manager.dart';
import 'package:airo_app/features/games/domain/services/chess_engine.dart';
import 'package:airo_app/features/games/domain/services/chess_tts_manager.dart';
import 'package:airo_app/features/games/domain/services/move_event_dispatcher.dart';
import 'package:airo_app/features/games/presentation/flame/chess_game.dart';
import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChessGameFlame startup', () {
    test('keeps the player turn when white starts', () async {
      final engine = _TestChessEngine();
      final game = ChessGameFlame(
        difficulty: ChessDifficulty.easy,
        engineOverride: engine,
        audioManagerOverride: _NoopAudioManager(),
        voicePlayerOverride: _NoopVoicePlayer(),
        initialPlayerColor: ChessColor.white,
        aiThinkingDelayOverride: Duration.zero,
      );

      game.onGameResize(Vector2(800, 800));
      await game.onLoad();

      expect(game.playerColor, ChessColor.white);
      expect(game.aiColor, ChessColor.black);
      expect(game.isPlayerTurn, isTrue);
      expect(engine.moveCount, 0);
    });

    test('lets the AI open when the player starts as black', () async {
      final engine = _TestChessEngine();
      final game = ChessGameFlame(
        difficulty: ChessDifficulty.easy,
        engineOverride: engine,
        audioManagerOverride: _NoopAudioManager(),
        voicePlayerOverride: _NoopVoicePlayer(),
        initialPlayerColor: ChessColor.black,
        aiThinkingDelayOverride: Duration.zero,
      );

      game.onGameResize(Vector2(800, 800));
      await game.onLoad();

      expect(game.playerColor, ChessColor.black);
      expect(game.aiColor, ChessColor.white);
      expect(game.isPlayerTurn, isTrue);
      expect(engine.moveCount, 1);
      expect(
        game.lastMove,
        const ChessMove(from: ChessSquare(12), to: ChessSquare(28)),
      );
    });

    test('flips display rows for white perspective only', () {
      expect(
        ChessGameFlame.displayRowForPlayerPerspective(0, ChessColor.white),
        7,
      );
      expect(
        ChessGameFlame.displayRowForPlayerPerspective(7, ChessColor.white),
        0,
      );
      expect(
        ChessGameFlame.displayRowForPlayerPerspective(0, ChessColor.black),
        0,
      );
      expect(
        ChessGameFlame.displayRowForPlayerPerspective(7, ChessColor.black),
        7,
      );
    });
  });
}

class _NoopAudioManager implements ChessAudioManager {
  @override
  Future<void> dispose() async {}

  @override
  Future<void> playBackgroundMusic(ChessBoardState board) async {}

  @override
  Future<void> playCaptureStinger() async {}

  @override
  Future<void> playCheckStinger() async {}

  @override
  Future<void> playCheckmateStinger() async {}

  @override
  Future<void> playVoiceLine(ChessAudioEvent event) async {}

  @override
  void setMusicEnabled(bool enabled) {}

  @override
  void setVoiceLinesEnabled(bool enabled) {}

  @override
  void setVolume(double volume) {}

  @override
  Future<void> stopBackgroundMusic() async {}
}

class _NoopVoicePlayer implements ChessVoicePlayer {
  @override
  Future<void> dispose() async {}

  @override
  Future<void> initialize() async {}

  @override
  Future<String> playMoveVoice(
    MoveEvent event, {
    required bool isPlayerMove,
  }) async {
    return '';
  }
}

class _TestChessEngine with ChessEngineAsync implements ChessEngine {
  ChessBoardState _state = ChessBoardState.initial();
  int moveCount = 0;

  @override
  List<ChessMove> getLegalMoves() {
    return const [
      ChessMove(from: ChessSquare(12), to: ChessSquare(28)),
      ChessMove(from: ChessSquare(52), to: ChessSquare(36)),
    ];
  }

  @override
  bool makeMove(ChessMove move) {
    final squares = List<ChessPiece?>.from(_state.squares);
    final piece = squares[move.from.index];
    squares[move.from.index] = null;
    squares[move.to.index] = piece;
    moveCount += 1;
    _state = ChessBoardState(
      squares: squares,
      toMove: _state.toMove == ChessColor.white
          ? ChessColor.black
          : ChessColor.white,
      whiteCanCastleKingside: _state.whiteCanCastleKingside,
      whiteCanCastleQueenside: _state.whiteCanCastleQueenside,
      blackCanCastleKingside: _state.blackCanCastleKingside,
      blackCanCastleQueenside: _state.blackCanCastleQueenside,
      enPassantSquare: _state.enPassantSquare,
      halfmoveClock: _state.halfmoveClock,
      fullmoveNumber: _state.fullmoveNumber,
      moveHistory: [..._state.moveHistory, move],
    );
    return true;
  }

  @override
  bool undoMove() => false;

  @override
  Future<ChessMove?> getBestMove({required ChessDifficulty difficulty}) async {
    return const ChessMove(from: ChessSquare(12), to: ChessSquare(28));
  }

  @override
  int evaluatePosition() => 0;

  @override
  void fromFEN(String fen) {}

  @override
  ChessBoardState getBoardState() => _state;

  @override
  bool isCheck() => false;

  @override
  bool isCheckmate() => false;

  @override
  bool isStalemate() => false;

  @override
  void reset() {
    _state = ChessBoardState.initial();
    moveCount = 0;
  }

  @override
  String toFEN() => '';

  @override
  Future<void> waitForReady() async {}
}
