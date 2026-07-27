import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:feature_iptv/presentation/widgets/player_lock_button.dart';

void main() {
  // Icon orientation is state-display (an open lock while controls are
  // usable, a closed lock while locked), flipped intentionally in #1059's
  // TV-surface consolidation — video_player_widget_test codifies the same
  // orientation for the full player. This unit test was left asserting the
  // pre-#1059 orientation and has failed deterministically since.
  testWidgets('shows an open lock icon when unlocked', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: PlayerLockButton(locked: false, onToggle: () {})),
    );
    expect(find.byIcon(Icons.lock_open), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsNothing);
  });

  testWidgets('shows a closed lock icon when locked', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: PlayerLockButton(locked: true, onToggle: () {})),
    );
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.byIcon(Icons.lock_open), findsNothing);
  });

  testWidgets('tapping calls onToggle', (tester) async {
    var toggled = false;
    await tester.pumpWidget(
      MaterialApp(
        home: PlayerLockButton(locked: false, onToggle: () => toggled = true),
      ),
    );
    await tester.tap(find.byType(PlayerLockButton));
    expect(toggled, isTrue);
  });
}
