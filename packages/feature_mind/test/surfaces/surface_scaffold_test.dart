import 'package:feature_mind/feature_mind.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/mind_rule_harness.dart';
import '../support/surface_harness.dart';

void main() {
  testWidgets('a live surface carries its pip and its numbers', (tester) async {
    await pumpSurface(
      tester,
      const MindSurfaceScaffold(
        title: 'MIND',
        status: MindSurfaceStatus.live(
          opCount: 12481,
          peerCount: 3,
          vaultSealed: true,
        ),
        child: SizedBox.shrink(),
      ),
    );

    expect(find.text('MIND'), findsOneWidget);
    expect(find.text('12,481 ops'), findsOneWidget);
    expect(find.text('3 on LAN'), findsOneWidget);
    await expectSatisfiesMindRules(tester);
  });

  testWidgets('an unavailable surface names the port, not the product', (
    tester,
  ) async {
    await pumpSurface(
      tester,
      const MindSurfaceScaffold(
        title: 'DEVICES',
        status: MindSurfaceStatus.unavailable(
          'MeshPort',
          'not implemented yet — #1200',
        ),
        child: SizedBox.shrink(),
      ),
    );

    expect(find.textContaining('MeshPort'), findsOneWidget);
    expect(find.textContaining('#1200'), findsOneWidget);
    // No fabricated numbers: a strip reading "0 ops" here would be a lie, not
    // an empty state.
    expect(find.byType(MindNumberStrip), findsNothing);
  });

  testWidgets('a rebuilding surface shows progress, never a bare spinner', (
    tester,
  ) async {
    await pumpSurface(
      tester,
      const MindSurfaceScaffold(
        title: 'MEMORY',
        status: MindSurfaceStatus.rebuilding(
          opsProcessed: 6240,
          opsTotal: 12481,
        ),
        child: SizedBox.shrink(),
      ),
    );

    expect(find.text('6,240 of 12,481 ops'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('the pip reports remote work when the runtime is not local', (
    tester,
  ) async {
    await pumpSurface(
      tester,
      const MindSurfaceScaffold(
        title: 'MIND',
        status: MindSurfaceStatus.live(
          opCount: 1,
          peerCount: 0,
          vaultSealed: true,
          isLocal: false,
          remoteLabel: 'iPad Air',
        ),
        child: SizedBox.shrink(),
      ),
    );

    expect(find.text('iPad Air'), findsOneWidget);
    expect(find.text('ON-DEVICE'), findsNothing);
  });
}
