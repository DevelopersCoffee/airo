import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('paints an isolated ribbon while active', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(width: 320, height: 64, child: AiroStreamGlow()),
        ),
      ),
    );
    await tester.pump();

    expect(tester.binding.hasScheduledFrame, isTrue);
    expect(find.byKey(const ValueKey('airo-stream-glow')), findsOneWidget);
    expect(find.byType(AiroRepaintIsland), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('paints nothing when inactive', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 320,
          height: 64,
          child: AiroStreamGlow(active: false),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('airo-stream-glow')), findsNothing);
  });

  testWidgets('reduced motion keeps a still ribbon', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: SizedBox(width: 320, height: 64, child: AiroStreamGlow()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(find.byKey(const ValueKey('airo-stream-glow')), findsOneWidget);
  });

  testWidgets('a loud level still lays out inside the given box', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            width: 320,
            height: 64,
            child: AiroStreamGlow(level: 4),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      tester.getSize(find.byKey(const ValueKey('airo-stream-glow'))),
      const Size(320, 64),
    );
  });
}
