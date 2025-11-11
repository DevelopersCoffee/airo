import 'package:flutter_tts/flutter_tts.dart';
import '../models/chess_models.dart';
import 'move_event_dispatcher.dart';

/// Text-to-Speech manager for chess game voice lines
/// Generates real-time DotA-style voice responses using TTS
class ChessTTSManager {
  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;
  bool _isSpeaking = false;

  /// Initialize TTS with custom settings
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Configure TTS settings
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(0.5); // Slightly faster for dramatic effect
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0); // Normal pitch

      // Set up callbacks
      _tts.setStartHandler(() {
        _isSpeaking = true;
      });

      _tts.setCompletionHandler(() {
        _isSpeaking = false;
      });

      _tts.setErrorHandler((msg) {
        print('[TTS] Error: $msg');
        _isSpeaking = false;
      });

      _isInitialized = true;
      print('[TTS] Initialized successfully');
    } catch (e) {
      print('[TTS] Initialization error: $e');
    }
  }

  /// Speak a voice line with optional pitch/rate customization
  Future<void> speak(
    String text, {
    double? pitch,
    double? rate,
    bool interrupt = false,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      // Stop current speech if interrupt is true
      if (interrupt && _isSpeaking) {
        await _tts.stop();
      }

      // Apply custom settings if provided
      if (pitch != null) await _tts.setPitch(pitch);
      if (rate != null) await _tts.setSpeechRate(rate);

      // Speak the text
      await _tts.speak(text);

      // Reset to defaults after speaking
      if (pitch != null) await _tts.setPitch(1.0);
      if (rate != null) await _tts.setSpeechRate(0.5);
    } catch (e) {
      print('[TTS] Speak error: $e');
    }
  }

  /// Stop current speech
  Future<void> stop() async {
    if (_isInitialized) {
      await _tts.stop();
      _isSpeaking = false;
    }
  }

  /// Dispose TTS resources
  Future<void> dispose() async {
    if (_isInitialized) {
      await _tts.stop();
      _isInitialized = false;
      _isSpeaking = false;
      print('[TTS] Disposed');
    }
  }

  /// Play move voice line based on move event
  Future<String> playMoveVoice(
    MoveEvent event, {
    required bool isPlayerMove,
  }) async {
    final voiceLine = _getDotAVoiceLine(event, isPlayerMove: isPlayerMove);

    // Customize voice based on who's moving
    final pitch = isPlayerMove
        ? 1.1
        : 0.9; // Higher pitch for player, lower for AI
    final rate = event.isCheckmate ? 0.4 : 0.5; // Slower for dramatic checkmate

    await speak(voiceLine, pitch: pitch, rate: rate, interrupt: false);

    return voiceLine; // Return the voice line for display
  }

  /// Get DotA-style voice line for a move event
  String _getDotAVoiceLine(MoveEvent event, {required bool isPlayerMove}) {
    final piece = event.piece;
    final isCapture = event.isCapture;
    final isCheck = event.isCheck;
    final isCheckmate = event.isCheckmate;

    // Checkmate responses (DotA 2 style)
    if (isCheckmate) {
      return isPlayerMove
          ? _getRandomFrom([
              'Checkmate! Victory is mine!',
              'GG! Too easy!',
              'Dominated! Better luck next time!',
              'Checkmate! Outplayed!',
              'Victory! Well calculated!',
              'Game over! I win!',
              'Rekt! Ancient destroyed!',
              'Mega creeps! It\'s over!',
              'Throne falls! Victory!',
              'Rampage! Checkmate!',
              'Beyond godlike! Checkmate!',
            ])
          : _getRandomFrom([
              'Checkmate... You got me.',
              'Well played. I concede.',
              'Defeated... Impressive.',
              'You win this round.',
              'Checkmate. Your victory.',
              'GG. Well played.',
              'Outplayed. Respect.',
              'My throne has fallen.',
            ]);
    }

    // Check responses (DotA 2 style)
    if (isCheck) {
      return isPlayerMove
          ? _getRandomFrom([
              'Check! Your king is in danger!',
              'Check! Better watch out!',
              'Check! Can you escape?',
              'Check! The pressure is on!',
              'Check! Your throne is under attack!',
              'Check! First blood on the king!',
              'Check! Gank incoming!',
            ])
          : _getRandomFrom([
              'Check! My turn to attack!',
              'Check! Your move!',
              'Check! Let\'s see you escape!',
              'Check! Initiation successful!',
              'Check! Caught out of position!',
            ]);
    }

    // Piece-specific responses
    switch (piece) {
      case PieceType.pawn:
        if (isCapture) {
          return _getRandomFrom([
            'Pawn takes! Small but mighty!',
            'Pawn captures! Every piece counts!',
            'Pawn strike! The little guy wins!',
            'Creep deny! Pawn takes!',
            'Lane creep scores a kill!',
            'Support gets the kill!',
          ]);
        } else {
          return _getRandomFrom([
            'Pawn advances. Small steps, big dreams.',
            'Pawn moves. The foundation strengthens!',
            'Pawn forward. Building pressure!',
            'Creep wave pushing!',
            'Lane pressure building!',
            'Farming the lane!',
          ]);
        }

      case PieceType.knight:
        if (isCapture) {
          return _getRandomFrom([
            'Knight takes! Forking like a boss!',
            'Knight captures! The horse strikes!',
            'Knight attack! Unexpected and deadly!',
            'Blink dagger! Knight strikes!',
            'Ganked! Knight takes!',
            'Initiation! Knight captures!',
            'Smoke gank successful!',
          ]);
        } else {
          return _getRandomFrom([
            'Knight repositions. Always unpredictable!',
            'Knight jumps! The cavalry moves!',
            'Knight maneuver. Tactical genius!',
            'Roaming for kills!',
            'Rotating mid!',
            'Setting up the gank!',
          ]);
        }

      case PieceType.bishop:
        if (isCapture) {
          return _getRandomFrom([
            'Bishop strikes! The diagonals deliver!',
            'Bishop captures! Long-range precision!',
            'Bishop takes! The diagonal assassin!',
            'Sniper shot! Bishop takes!',
            'Long range nuke!',
            'Skillshot landed!',
          ]);
        } else {
          return _getRandomFrom([
            'Bishop develops. The diagonals are mine!',
            'Bishop slides. Controlling the board!',
            'Bishop moves. Long-range power!',
            'Positioning for the shot!',
            'Vision control!',
            'Map awareness!',
          ]);
        }

      case PieceType.rook:
        if (isCapture) {
          return _getRandomFrom([
            'Rook smash! No escape!',
            'Rook captures! The tower falls!',
            'Rook takes! Brute force wins!',
            'Tower dive! Rook takes!',
            'Siege damage! Rook captures!',
            'Pushing high ground!',
          ]);
        } else {
          return _getRandomFrom([
            'Rook moves. The tower shifts!',
            'Rook repositions. Power play!',
            'Rook slides. Controlling files!',
            'Tower positioning!',
            'Siege creep advancing!',
            'High ground secured!',
          ]);
        }

      case PieceType.queen:
        if (isCapture) {
          return _getRandomFrom([
            'Queen takes! Bow before her majesty!',
            'Queen captures! The most powerful piece!',
            'Queen strikes! Unstoppable!',
            'Carry is fed! Queen takes!',
            'Six slotted! Queen dominates!',
            'Ultra kill! Queen captures!',
            'Godlike! Queen unstoppable!',
          ]);
        } else {
          return _getRandomFrom([
            'My queen enters the fray!',
            'Queen moves. The board trembles!',
            'Queen repositions. Ultimate power!',
            'Carry farming!',
            'Getting items!',
            'Power spike incoming!',
          ]);
        }

      case PieceType.king:
        if (isCapture) {
          return _getRandomFrom([
            'King takes! The monarch fights!',
            'King captures! Royal intervention!',
            'Ancient fights back!',
            'Throne defends itself!',
          ]);
        } else {
          return _getRandomFrom([
            'King moves. Safety first!',
            'King repositions. Protecting the throne!',
            'King steps. Careful now!',
            'Ancient repositioning!',
            'Throne under pressure!',
            'Defending the base!',
            'Buy back available!',
          ]);
        }
    }
  }

  /// Get random element from list
  String _getRandomFrom(List<String> options) {
    return options[DateTime.now().millisecondsSinceEpoch % options.length];
  }
}
