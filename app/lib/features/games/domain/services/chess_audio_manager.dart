import '../models/chess_models.dart';

/// Tone/personality for voice lines
enum VoiceTone { smug, sarcastic, dramatic, annoyed, victory, despair }

/// Audio event for a chess move
class ChessAudioEvent {
  final PieceType piece;
  final MoveClassification classification;
  final VoiceTone tone;
  final String audioPath;
  final Duration cooldown;

  const ChessAudioEvent({
    required this.piece,
    required this.classification,
    required this.tone,
    required this.audioPath,
    required this.cooldown,
  });
}

/// Chess audio manager interface
abstract class ChessAudioManager {
  /// Play voice line for a move
  Future<void> playVoiceLine(ChessAudioEvent event);

  /// Play background music based on game state
  Future<void> playBackgroundMusic(ChessBoardState board);

  /// Stop background music
  Future<void> stopBackgroundMusic();

  /// Play capture stinger
  Future<void> playCaptureStinger();

  /// Play check stinger
  Future<void> playCheckStinger();

  /// Play checkmate stinger
  Future<void> playCheckmateStinger();

  /// Toggle voice lines on/off
  void setVoiceLinesEnabled(bool enabled);

  /// Toggle music on/off
  void setMusicEnabled(bool enabled);

  /// Set volume (0.0 - 1.0)
  void setVolume(double volume);

  /// Dispose resources
  Future<void> dispose();
}

/// Fake chess audio manager for development
class FakeChessAudioManager implements ChessAudioManager {
  bool _voiceLinesEnabled = true;
  bool _musicEnabled = true;
  double _volume = 0.8;
  final Map<PieceType, List<String>> _voiceLines = {
    PieceType.pawn: [
      'A footsoldier did that.',
      'Pawn power.',
      'One step at a time.',
    ],
    PieceType.knight: [
      'Two problems. One horse.',
      'Knight moves in mysterious ways.',
      'L-shaped destiny.',
    ],
    PieceType.bishop: [
      'Geometry hurts.',
      'Diagonal domination.',
      'The bishop has spoken.',
    ],
    PieceType.rook: [
      'Corridor secured.',
      'Straight and narrow.',
      'Rook solid.',
    ],
    PieceType.queen: [
      'The queen reigns supreme.',
      'Royal flush.',
      'Majesty in motion.',
    ],
    PieceType.king: ['That tickled.', 'The king moves.', 'Royalty in retreat.'],
  };

  @override
  Future<void> playVoiceLine(ChessAudioEvent event) async {
    if (!_voiceLinesEnabled) return;
    // Simulate audio playback
    print(
      '[AUDIO] Playing voice line: ${event.audioPath} (${event.piece.name})',
    );
  }

  @override
  Future<void> playBackgroundMusic(ChessBoardState board) async {
    if (!_musicEnabled) return;
    // Determine music based on game state
    final moveCount = board.moveHistory.length;
    String track;
    if (moveCount < 10) {
      track = 'calm_opening.mp3';
    } else if (moveCount < 30) {
      track = 'midgame_tension.mp3';
    } else {
      track = 'endgame_heroic.mp3';
    }
    print('[AUDIO] Playing background music: $track');
  }

  @override
  Future<void> stopBackgroundMusic() async {
    print('[AUDIO] Stopping background music');
  }

  @override
  Future<void> playCaptureStinger() async {
    if (!_musicEnabled) return;
    print('[AUDIO] Playing capture stinger');
  }

  @override
  Future<void> playCheckStinger() async {
    if (!_musicEnabled) return;
    print('[AUDIO] Playing check stinger');
  }

  @override
  Future<void> playCheckmateStinger() async {
    if (!_musicEnabled) return;
    print('[AUDIO] Playing checkmate stinger');
  }

  @override
  void setVoiceLinesEnabled(bool enabled) {
    _voiceLinesEnabled = enabled;
    print('[AUDIO] Voice lines: ${enabled ? 'enabled' : 'disabled'}');
  }

  @override
  void setMusicEnabled(bool enabled) {
    _musicEnabled = enabled;
    print('[AUDIO] Music: ${enabled ? 'enabled' : 'disabled'}');
  }

  @override
  void setVolume(double volume) {
    _volume = volume.clamp(0.0, 1.0);
    print('[AUDIO] Volume set to: $_volume');
  }

  @override
  Future<void> dispose() async {
    print('[AUDIO] Disposing audio manager');
  }

  /// Get random voice line for piece
  String getRandomVoiceLine(PieceType piece) {
    final lines = _voiceLines[piece] ?? [];
    return lines.isNotEmpty
        ? lines[DateTime.now().millisecond % lines.length]
        : '';
  }
}
