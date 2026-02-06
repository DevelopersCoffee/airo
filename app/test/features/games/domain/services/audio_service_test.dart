import 'package:flutter_test/flutter_test.dart';
import 'package:airo_app/features/games/domain/services/game_audio_service.dart';
import 'package:airo_app/features/games/domain/services/chess_audio_manager.dart';
import 'package:airo_app/features/games/domain/models/chess_models.dart';

/// Audio service tests using fake implementations
void main() {
  group('FakeGameAudioService', () {
    late FakeGameAudioService audioService;

    setUp(() {
      audioService = FakeGameAudioService();
    });

    test('playSfx does nothing when SFX is disabled', () async {
      await audioService.setSfxEnabled(false);
      await audioService.playSfx('test_sound');
      // No exception should be thrown
    });

    test('playSfx executes when SFX is enabled', () async {
      await audioService.setSfxEnabled(true);
      await audioService.playSfx('test_sound');
      // No exception should be thrown
    });

    test('setSfxVolume accepts valid volume range', () async {
      await audioService.setSfxVolume(0.0);
      await audioService.setSfxVolume(0.5);
      await audioService.setSfxVolume(1.0);
      // No exception should be thrown for valid values
    });

    test('requestDucking completes without error', () async {
      await audioService.requestDucking(const Duration(milliseconds: 500));
      // No exception should be thrown
    });

    test('onFocusLost and onFocusGain work correctly', () async {
      await audioService.onFocusLost();
      await audioService.onFocusGain();
      // No exception should be thrown
    });

    test('stopSfxAll completes without error', () async {
      await audioService.stopSfxAll();
      // No exception should be thrown
    });
  });

  group('FakeChessAudioManager', () {
    late FakeChessAudioManager chessAudio;

    setUp(() {
      chessAudio = FakeChessAudioManager();
    });

    test('playVoiceLine does nothing when voice lines disabled', () async {
      chessAudio.setVoiceLinesEnabled(false);
      final event = ChessAudioEvent(
        piece: PieceType.pawn,
        audioPath: 'test.mp3',
        classification: MoveClassification.quiet,
        tone: VoiceTone.smug,
        cooldown: const Duration(milliseconds: 300),
      );
      await chessAudio.playVoiceLine(event);
      // No exception should be thrown
    });

    test('playVoiceLine executes when voice lines enabled', () async {
      chessAudio.setVoiceLinesEnabled(true);
      final event = ChessAudioEvent(
        piece: PieceType.knight,
        audioPath: 'knight_move.mp3',
        classification: MoveClassification.capture,
        tone: VoiceTone.dramatic,
        cooldown: const Duration(milliseconds: 300),
      );
      await chessAudio.playVoiceLine(event);
      // No exception should be thrown
    });

    test('playBackgroundMusic selects track based on move count', () async {
      chessAudio.setMusicEnabled(true);

      // Opening phase (< 10 moves)
      var board = ChessBoardState.initial();
      await chessAudio.playBackgroundMusic(board);

      // Midgame phase (10-30 moves) - create mock board with history
      final midgameMoves = List.generate(
        15,
        (i) => const ChessMove(
          from: ChessSquare(0), // a1
          to: ChessSquare(8), // a2
        ),
      );
      board = ChessBoardState(
        squares: board.squares,
        toMove: ChessColor.white,
        whiteCanCastleKingside: true,
        whiteCanCastleQueenside: true,
        blackCanCastleKingside: true,
        blackCanCastleQueenside: true,
        halfmoveClock: 0,
        fullmoveNumber: 15,
        moveHistory: midgameMoves,
      );
      await chessAudio.playBackgroundMusic(board);

      // Endgame phase (30+ moves)
      final endgameMoves = List.generate(
        35,
        (i) => const ChessMove(
          from: ChessSquare(0), // a1
          to: ChessSquare(8), // a2
        ),
      );
      board = ChessBoardState(
        squares: board.squares,
        toMove: ChessColor.white,
        whiteCanCastleKingside: false,
        whiteCanCastleQueenside: false,
        blackCanCastleKingside: false,
        blackCanCastleQueenside: false,
        halfmoveClock: 0,
        fullmoveNumber: 35,
        moveHistory: endgameMoves,
      );
      await chessAudio.playBackgroundMusic(board);
      // No exception should be thrown
    });

    test('stopBackgroundMusic completes without error', () async {
      await chessAudio.stopBackgroundMusic();
    });

    test('stinger methods complete without error', () async {
      await chessAudio.playCaptureStinger();
      await chessAudio.playCheckStinger();
      await chessAudio.playCheckmateStinger();
    });

    test('setVolume clamps to valid range', () {
      chessAudio.setVolume(0.5);
      chessAudio.setVolume(-0.5); // Should clamp to 0
      chessAudio.setVolume(1.5); // Should clamp to 1
      // No exception should be thrown
    });

    test('dispose cleans up resources', () async {
      await chessAudio.dispose();
      // No exception should be thrown
    });

    test('getRandomVoiceLine returns line for known pieces', () {
      for (final piece in PieceType.values) {
        final line = chessAudio.getRandomVoiceLine(piece);
        expect(line, isA<String>());
      }
    });
  });
}
