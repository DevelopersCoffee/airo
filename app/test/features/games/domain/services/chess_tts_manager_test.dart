import 'package:flutter_test/flutter_test.dart';
import 'package:airo_app/features/games/domain/models/chess_models.dart';
import 'package:airo_app/features/games/domain/services/move_event_dispatcher.dart';

/// Fake TTS client for testing voice move announcements
class FakeTTSClient {
  final List<String> spokenTexts = [];
  bool isInitialized = false;

  Future<void> initialize() async {
    isInitialized = true;
  }

  Future<void> speak(String text) async {
    spokenTexts.add(text);
  }

  void clear() {
    spokenTexts.clear();
  }
}

/// Testable TTS manager that uses FakeTTSClient
class TestableTTSManager {
  final FakeTTSClient _tts;

  TestableTTSManager(this._tts);

  Future<void> initialize() async {
    await _tts.initialize();
  }

  /// Get human-readable move notation
  String getMoveNotation(MoveEvent event) {
    final pieceName = _getPieceName(event.piece);
    final toSquare = event.move.to.toAlgebraic();

    // Check for castling (king moves 2 squares)
    if (event.piece == PieceType.king) {
      final fromFile = event.move.from.file;
      final toFile = event.move.to.file;
      if ((fromFile - toFile).abs() == 2) {
        return toFile > fromFile ? 'Castles kingside' : 'Castles queenside';
      }
    }

    // Check for promotion
    if (event.move.promotion != null) {
      final promotedTo = _getPieceName(event.move.promotion!);
      if (event.isCapture) {
        return 'Pawn takes and promotes to $promotedTo on $toSquare';
      }
      return 'Pawn promotes to $promotedTo on $toSquare';
    }

    // Normal move or capture
    if (event.isCapture) {
      return '$pieceName takes on $toSquare';
    }
    return '$pieceName to $toSquare';
  }

  String _getPieceName(PieceType piece) {
    switch (piece) {
      case PieceType.pawn:
        return 'Pawn';
      case PieceType.knight:
        return 'Knight';
      case PieceType.bishop:
        return 'Bishop';
      case PieceType.rook:
        return 'Rook';
      case PieceType.queen:
        return 'Queen';
      case PieceType.king:
        return 'King';
    }
  }

  Future<void> speakMoveNotation(MoveEvent event) async {
    final notation = getMoveNotation(event);
    await _tts.speak(notation);
  }
}

MoveEvent _createMoveEvent({
  required ChessMove move,
  required PieceType piece,
  bool isCapture = false,
  bool isCheck = false,
  bool isCheckmate = false,
}) {
  return MoveEvent(
    move: move,
    piece: piece,
    classification: isCheckmate
        ? MoveClassification.checkmate
        : isCheck
            ? MoveClassification.check
            : isCapture
                ? MoveClassification.capture
                : MoveClassification.quiet,
    isCapture: isCapture,
    isCheck: isCheck,
    isCheckmate: isCheckmate,
    timestamp: DateTime.now(),
  );
}

void main() {
  group('Chess TTS Manager - Move Announcements', () {
    late FakeTTSClient fakeTTS;
    late TestableTTSManager ttsManager;

    setUp(() {
      fakeTTS = FakeTTSClient();
      ttsManager = TestableTTSManager(fakeTTS);
    });

    test('announces knight move correctly', () async {
      final event = _createMoveEvent(
        move: const ChessMove(
          from: ChessSquare(6), // g1
          to: ChessSquare(21), // f3
        ),
        piece: PieceType.knight,
      );

      await ttsManager.speakMoveNotation(event);
      expect(fakeTTS.spokenTexts, ['Knight to f3']);
    });

    test('announces capture correctly', () async {
      final event = _createMoveEvent(
        move: const ChessMove(
          from: ChessSquare(27), // d4
          to: ChessSquare(36), // e5
        ),
        piece: PieceType.bishop,
        isCapture: true,
      );

      await ttsManager.speakMoveNotation(event);
      expect(fakeTTS.spokenTexts, ['Bishop takes on e5']);
    });

    test('announces kingside castling correctly', () async {
      final event = _createMoveEvent(
        move: const ChessMove(
          from: ChessSquare(4), // e1
          to: ChessSquare(6), // g1
        ),
        piece: PieceType.king,
      );

      await ttsManager.speakMoveNotation(event);
      expect(fakeTTS.spokenTexts, ['Castles kingside']);
    });

    test('announces queenside castling correctly', () async {
      final event = _createMoveEvent(
        move: const ChessMove(
          from: ChessSquare(4), // e1
          to: ChessSquare(2), // c1
        ),
        piece: PieceType.king,
      );

      await ttsManager.speakMoveNotation(event);
      expect(fakeTTS.spokenTexts, ['Castles queenside']);
    });

    test('announces pawn promotion correctly', () async {
      final event = _createMoveEvent(
        move: const ChessMove(
          from: ChessSquare(48), // a7
          to: ChessSquare(56), // a8
          promotion: PieceType.queen,
        ),
        piece: PieceType.pawn,
      );

      await ttsManager.speakMoveNotation(event);
      expect(fakeTTS.spokenTexts, ['Pawn promotes to Queen on a8']);
    });

    test('announces pawn promotion with capture correctly', () async {
      final event = _createMoveEvent(
        move: const ChessMove(
          from: ChessSquare(48), // a7
          to: ChessSquare(57), // b8
          promotion: PieceType.knight,
        ),
        piece: PieceType.pawn,
        isCapture: true,
      );

      await ttsManager.speakMoveNotation(event);
      expect(fakeTTS.spokenTexts, ['Pawn takes and promotes to Knight on b8']);
    });

    test('announces queen move correctly', () async {
      final event = _createMoveEvent(
        move: const ChessMove(
          from: ChessSquare(3), // d1
          to: ChessSquare(39), // h5
        ),
        piece: PieceType.queen,
      );

      await ttsManager.speakMoveNotation(event);
      expect(fakeTTS.spokenTexts, ['Queen to h5']);
    });

    test('announces rook capture correctly', () async {
      final event = _createMoveEvent(
        move: const ChessMove(
          from: ChessSquare(0), // a1
          to: ChessSquare(56), // a8
        ),
        piece: PieceType.rook,
        isCapture: true,
      );

      await ttsManager.speakMoveNotation(event);
      expect(fakeTTS.spokenTexts, ['Rook takes on a8']);
    });

    test('announces pawn move correctly', () async {
      final event = _createMoveEvent(
        move: const ChessMove(
          from: ChessSquare(12), // e2
          to: ChessSquare(28), // e4
        ),
        piece: PieceType.pawn,
      );

      await ttsManager.speakMoveNotation(event);
      expect(fakeTTS.spokenTexts, ['Pawn to e4']);
    });
  });
}

