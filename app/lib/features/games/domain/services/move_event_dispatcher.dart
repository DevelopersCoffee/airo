import 'package:flutter/foundation.dart';
import '../models/chess_models.dart';

/// Move event with classification and metadata
class MoveEvent {
  final ChessMove move;
  final PieceType piece;
  final MoveClassification classification;
  final bool isCapture;
  final bool isCheck;
  final bool isCheckmate;
  final int? evaluation; // Engine evaluation
  final DateTime timestamp;

  const MoveEvent({
    required this.move,
    required this.piece,
    required this.classification,
    required this.isCapture,
    required this.isCheck,
    required this.isCheckmate,
    this.evaluation,
    required this.timestamp,
  });
}

/// Move event listener callback
typedef MoveEventListener = void Function(MoveEvent event);

/// Move event dispatcher
class MoveEventDispatcher extends ChangeNotifier {
  final List<MoveEventListener> _listeners = [];
  final Map<PieceType, DateTime> _lastPlayedTime = {};
  static const Duration _globalCooldown = Duration(milliseconds: 300);
  static const Duration _pieceCooldown = Duration(milliseconds: 500);

  /// Add listener for move events
  void addMoveListener(MoveEventListener listener) {
    _listeners.add(listener);
  }

  /// Remove listener
  void removeMoveListener(MoveEventListener listener) {
    _listeners.remove(listener);
  }

  /// Dispatch a move event
  void dispatchMove(MoveEvent event) {
    // Check cooldowns
    if (!_canPlayAudio(event.piece)) {
      return;
    }

    // Update last played time
    _lastPlayedTime[event.piece] = DateTime.now();

    // Notify all listeners
    for (final listener in _listeners) {
      listener(event);
    }

    notifyListeners();
  }

  /// Check if audio can be played (cooldown check)
  bool _canPlayAudio(PieceType piece) {
    final lastPlayed = _lastPlayedTime[piece];
    if (lastPlayed == null) return true;

    final timeSinceLastPlay = DateTime.now().difference(lastPlayed);
    return timeSinceLastPlay >= _pieceCooldown;
  }

  /// Classify a move based on board state
  static MoveClassification classifyMove({
    required ChessMove move,
    required ChessBoardState boardBefore,
    required ChessBoardState boardAfter,
    required bool isCapture,
    required bool isCheck,
    required bool isCheckmate,
    int? evaluation,
  }) {
    if (isCheckmate) return MoveClassification.checkmate;
    if (isCheck) return MoveClassification.check;
    if (isCapture) return MoveClassification.capture;

    // Classify as blunder or brilliance based on evaluation change
    if (evaluation != null && evaluation < -200) {
      return MoveClassification.blunder;
    }
    if (evaluation != null && evaluation > 200) {
      return MoveClassification.brilliance;
    }

    return MoveClassification.quiet;
  }

  /// Create move event from move and board state
  static MoveEvent createMoveEvent({
    required ChessMove move,
    required PieceType piece,
    required ChessBoardState boardBefore,
    required ChessBoardState boardAfter,
    required bool isCapture,
    required bool isCheck,
    required bool isCheckmate,
    int? evaluation,
  }) {
    final classification = classifyMove(
      move: move,
      boardBefore: boardBefore,
      boardAfter: boardAfter,
      isCapture: isCapture,
      isCheck: isCheck,
      isCheckmate: isCheckmate,
      evaluation: evaluation,
    );

    return MoveEvent(
      move: move,
      piece: piece,
      classification: classification,
      isCapture: isCapture,
      isCheck: isCheck,
      isCheckmate: isCheckmate,
      evaluation: evaluation,
      timestamp: DateTime.now(),
    );
  }

  @override
  void dispose() {
    _listeners.clear();
    super.dispose();
  }
}
