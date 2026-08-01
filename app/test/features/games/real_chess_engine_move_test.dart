import 'package:airo_app/features/games/domain/models/chess_models.dart';
import 'package:airo_app/features/games/domain/services/real_chess_engine.dart';
import 'package:flutter_test/flutter_test.dart';

/// Moves have to actually reach the board.
///
/// Found on the rig Pixel 9 (issue #1407 investigation): Chess looked frozen —
/// the AI "moved", the last-move highlight appeared, but no piece ever changed
/// square. The cause is a notation mismatch. `_toAlgebraic` builds UCI
/// ("a2a4"), while `chess.dart`'s `move(String)` matches its argument against
/// **SAN** ("a4", "Nf3"). No SAN string ever equals a UCI string, so every move
/// was rejected. `makeMove` returned false and the single call site
/// (chess_game.dart) ignored the result, recording `lastMove` regardless.
///
/// These tests pin the engine boundary rather than the UI: a legal move must be
/// accepted and must move the piece, and an illegal move must be refused.
void main() {
  ChessMove moveBetween(String from, String to) {
    int indexOf(String square) {
      final file = square.codeUnitAt(0) - 'a'.codeUnitAt(0);
      final rank = int.parse(square[1]) - 1;
      return rank * 8 + file;
    }

    return ChessMove(
      from: ChessSquare(indexOf(from)),
      to: ChessSquare(indexOf(to)),
    );
  }

  group('makeMove applies the move to the board', () {
    test('a legal opening pawn move is accepted and moves the piece', () {
      final engine = RealChessEngine();
      final before = engine.getBoardState();

      expect(
        before.squares[12]?.color,
        ChessColor.white,
        reason: 'e2 holds a white pawn in the initial position',
      );
      expect(before.squares[28], isNull, reason: 'e4 starts empty');

      final accepted = engine.makeMove(moveBetween('e2', 'e4'));

      expect(
        accepted,
        isTrue,
        reason:
            'e2-e4 is legal from the initial position; rejecting it is the '
            'bug that made the board look frozen',
      );

      final after = engine.getBoardState();
      expect(after.squares[12], isNull, reason: 'e2 must be vacated');
      expect(
        after.squares[28]?.color,
        ChessColor.white,
        reason: 'the pawn must arrive on e4',
      );
    });

    test('a knight move is accepted', () {
      final engine = RealChessEngine();

      expect(engine.makeMove(moveBetween('g1', 'f3')), isTrue);
      expect(engine.getBoardState().squares[21]?.type, PieceType.knight);
    });

    test('an illegal move is refused and leaves the board untouched', () {
      final engine = RealChessEngine();

      // A rook cannot leave a1 in the initial position: it is boxed in.
      expect(engine.makeMove(moveBetween('a1', 'a5')), isFalse);

      final after = engine.getBoardState();
      expect(after.squares[0]?.type, PieceType.rook);
      expect(after.squares[32], isNull);
    });

    test('turn order advances, so the side to move alternates', () {
      final engine = RealChessEngine();

      expect(engine.getBoardState().toMove, ChessColor.white);
      expect(engine.makeMove(moveBetween('e2', 'e4')), isTrue);
      expect(
        engine.getBoardState().toMove,
        ChessColor.black,
        reason:
            'a rejected move would leave White to move forever, which is '
            'what stalled the game',
      );
    });
  });
}
