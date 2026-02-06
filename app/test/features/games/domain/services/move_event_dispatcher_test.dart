import 'package:flutter_test/flutter_test.dart';
import 'package:airo_app/features/games/domain/services/move_event_dispatcher.dart';
import 'package:airo_app/features/games/domain/models/chess_models.dart';

/// Move event dispatcher tests
void main() {
  group('MoveEventDispatcher', () {
    late MoveEventDispatcher dispatcher;

    setUp(() {
      dispatcher = MoveEventDispatcher();
    });

    tearDown(() {
      dispatcher.dispose();
    });

    test('notifies listeners when move is dispatched', () {
      final receivedEvents = <MoveEvent>[];

      dispatcher.addMoveListener((event) {
        receivedEvents.add(event);
      });

      final event = MoveEvent(
        move: const ChessMove(
          from: ChessSquare(12), // e2
          to: ChessSquare(28), // e4
        ),
        piece: PieceType.pawn,
        classification: MoveClassification.quiet,
        isCapture: false,
        isCheck: false,
        isCheckmate: false,
        timestamp: DateTime.now(),
      );

      dispatcher.dispatchMove(event);

      expect(receivedEvents.length, equals(1));
      expect(receivedEvents.first.piece, equals(PieceType.pawn));
    });

    test('removes listener correctly', () {
      final receivedEvents = <MoveEvent>[];

      void listener(MoveEvent event) {
        receivedEvents.add(event);
      }

      dispatcher.addMoveListener(listener);
      dispatcher.removeMoveListener(listener);

      final event = MoveEvent(
        move: const ChessMove(
          from: ChessSquare(1), // b1
          to: ChessSquare(18), // c3
        ),
        piece: PieceType.knight,
        classification: MoveClassification.quiet,
        isCapture: false,
        isCheck: false,
        isCheckmate: false,
        timestamp: DateTime.now(),
      );

      dispatcher.dispatchMove(event);

      expect(receivedEvents, isEmpty);
    });

    test('respects piece cooldown', () async {
      final receivedEvents = <MoveEvent>[];

      dispatcher.addMoveListener((event) {
        receivedEvents.add(event);
      });

      final event1 = MoveEvent(
        move: const ChessMove(
          from: ChessSquare(12), // e2
          to: ChessSquare(28), // e4
        ),
        piece: PieceType.pawn,
        classification: MoveClassification.quiet,
        isCapture: false,
        isCheck: false,
        isCheckmate: false,
        timestamp: DateTime.now(),
      );

      // First dispatch should go through
      dispatcher.dispatchMove(event1);
      expect(receivedEvents.length, equals(1));

      // Immediate second dispatch should be blocked by cooldown
      dispatcher.dispatchMove(event1);
      expect(receivedEvents.length, equals(1)); // Still 1

      // Wait for cooldown (500ms)
      await Future.delayed(const Duration(milliseconds: 600));

      // Now should go through
      dispatcher.dispatchMove(event1);
      expect(receivedEvents.length, equals(2));
    });
  });

  group('MoveClassification', () {
    final sampleBoard = ChessBoardState.initial();

    test('classifies checkmate correctly', () {
      final classification = MoveEventDispatcher.classifyMove(
        move: const ChessMove(
          from: ChessSquare(3), // d1
          to: ChessSquare(39), // h5
        ),
        boardBefore: sampleBoard,
        boardAfter: sampleBoard,
        isCapture: false,
        isCheck: false,
        isCheckmate: true,
      );

      expect(classification, equals(MoveClassification.checkmate));
    });

    test('classifies check correctly', () {
      final classification = MoveEventDispatcher.classifyMove(
        move: const ChessMove(
          from: ChessSquare(5), // f1
          to: ChessSquare(26), // c4
        ),
        boardBefore: sampleBoard,
        boardAfter: sampleBoard,
        isCapture: false,
        isCheck: true,
        isCheckmate: false,
      );

      expect(classification, equals(MoveClassification.check));
    });

    test('classifies capture correctly', () {
      final classification = MoveEventDispatcher.classifyMove(
        move: const ChessMove(
          from: ChessSquare(36), // e5
          to: ChessSquare(45), // f6
        ),
        boardBefore: sampleBoard,
        boardAfter: sampleBoard,
        isCapture: true,
        isCheck: false,
        isCheckmate: false,
      );

      expect(classification, equals(MoveClassification.capture));
    });

    test('classifies quiet move correctly', () {
      final classification = MoveEventDispatcher.classifyMove(
        move: const ChessMove(
          from: ChessSquare(12), // e2
          to: ChessSquare(28), // e4
        ),
        boardBefore: sampleBoard,
        boardAfter: sampleBoard,
        isCapture: false,
        isCheck: false,
        isCheckmate: false,
      );

      expect(classification, equals(MoveClassification.quiet));
    });

    test('classifies blunder based on negative evaluation', () {
      final classification = MoveEventDispatcher.classifyMove(
        move: const ChessMove(
          from: ChessSquare(3), // d1
          to: ChessSquare(24), // a4
        ),
        boardBefore: sampleBoard,
        boardAfter: sampleBoard,
        isCapture: false,
        isCheck: false,
        isCheckmate: false,
        evaluation: -300,
      );

      expect(classification, equals(MoveClassification.blunder));
    });

    test('classifies brilliance based on positive evaluation', () {
      final classification = MoveEventDispatcher.classifyMove(
        move: const ChessMove(
          from: ChessSquare(6), // g1
          to: ChessSquare(21), // f3
        ),
        boardBefore: sampleBoard,
        boardAfter: sampleBoard,
        isCapture: false,
        isCheck: false,
        isCheckmate: false,
        evaluation: 300,
      );

      expect(classification, equals(MoveClassification.brilliance));
    });
  });
}
