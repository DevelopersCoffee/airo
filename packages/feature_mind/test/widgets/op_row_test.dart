import 'package:feature_mind/feature_mind.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _verified = MindOp(
  sequence: 12388,
  kind: MindOpKind.scan,
  title: 'Invoice · Kitchen repair, Basu Contracting',
  contextId: 'q3taxfiling',
  deviceName: 'Pixel 9 Pro',
  signature: SignatureState.verified,
  recordedAtMs: 0,
);

void main() {
  testWidgets('shows the op number, because that is what gets cited', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MindOpRow(op: _verified)),
      ),
    );

    expect(find.text('op 12,388'), findsOneWidget);
    expect(
      find.text('Invoice · Kitchen repair, Basu Contracting'),
      findsOneWidget,
    );
  });

  testWidgets('attributes the op to the device that wrote it', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MindOpRow(op: _verified)),
      ),
    );

    expect(find.text('Pixel 9 Pro'), findsOneWidget);
  });

  testWidgets('an unverified signature looks different from a verified one', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const MindOpRow(op: _verified),
              MindOpRow(
                op: _verified.copyWith(signature: SignatureState.unverified),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('verified'), findsOneWidget);
    expect(find.text('UNVERIFIED'), findsOneWidget);

    final badges = tester
        .widgetList<Text>(find.byKey(const Key('mind.op.signature')))
        .toList();
    expect(badges.first.style?.color, isNot(badges.last.style?.color));
  });

  testWidgets('an unsigned op is not rendered as verified', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MindOpRow(
            op: _verified.copyWith(signature: SignatureState.unsigned),
          ),
        ),
      ),
    );

    expect(find.text('UNSIGNED'), findsOneWidget);
    expect(find.text('verified'), findsNothing);
  });

  testWidgets('tapping calls through when a handler is given', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MindOpRow(op: _verified, onTap: () => taps++),
        ),
      ),
    );

    await tester.tap(find.byType(MindOpRow));
    expect(taps, 1);
  });
}
