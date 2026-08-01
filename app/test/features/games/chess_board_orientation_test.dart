import 'package:airo_app/features/games/domain/models/chess_models.dart';
import 'package:airo_app/features/games/presentation/flame/chess_game.dart';
import 'package:flutter_test/flutter_test.dart';

/// Rank labels have to follow the same flip as the pieces.
///
/// Found on the rig Pixel 9 (issue #1375): the board looked like it had pawns
/// of the wrong colour on the a-file. The pieces were right — a device probe
/// confirmed the engine held `a2=white/pawn, a7=black/pawn` — but the labels
/// were drawn 8..1 top-to-bottom regardless of orientation, so the ranks read
/// upside down against the pieces and the position looked illegal.
///
/// `playerColor` is `random.nextBool()`, so this was wrong in about half of
/// all games, which is why it reproduced inconsistently.
void main() {
  group('rank labels match the rendered orientation', () {
    test('white at the bottom puts rank 8 on top and rank 1 at the bottom', () {
      final labels = [
        for (var displayRow = 0; displayRow < 8; displayRow++)
          ChessGameFlame.rankLabelForDisplayRow(displayRow, ChessColor.white),
      ];

      expect(labels, ['8', '7', '6', '5', '4', '3', '2', '1']);
    });

    test('black at the bottom puts rank 1 on top and rank 8 at the bottom', () {
      final labels = [
        for (var displayRow = 0; displayRow < 8; displayRow++)
          ChessGameFlame.rankLabelForDisplayRow(displayRow, ChessColor.black),
      ];

      expect(
        labels,
        ['1', '2', '3', '4', '5', '6', '7', '8'],
        reason:
            'a black player sees the board from the other side, so rank 1 is '
            'the far row; labelling it 8 is what made the position look wrong',
      );
    });
  });

  group('labels agree with where the pieces are drawn', () {
    for (final playerColor in ChessColor.values) {
      test('every rank label sits on that rank\'s own row for $playerColor', () {
        for (var boardRow = 0; boardRow < 8; boardRow++) {
          // Where _drawPieces puts this board row.
          final displayRow = ChessGameFlame.displayRowForPlayerPerspective(
            boardRow,
            playerColor,
          );
          // Board row 0 is rank 1 in this project's 64-square indexing.
          expect(
            ChessGameFlame.rankLabelForDisplayRow(displayRow, playerColor),
            '${boardRow + 1}',
            reason:
                'the digit drawn beside a row must name the rank whose pieces '
                'are drawn on it',
          );
        }
      });
    }
  });
}
