import 'package:feature_mind/src/runtime/models/log_models.dart';
import 'package:feature_mind/src/runtime_console/runtime_console_controller.dart';
import 'package:feature_mind/src/runtime_console/runtime_console_models.dart';
import 'package:feature_mind/src/runtime_console/runtime_console_table.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_operation_log_port.dart';

Future<void> _pumpConsole(
  WidgetTester tester,
  RuntimeConsoleController controller, {
  TargetPlatform platform = TargetPlatform.windows,
}) async {
  // Tall enough that every seeded row in these tests actually builds inside
  // the virtualised ListView, rather than sitting off-screen and never being
  // laid out — a real desktop window is this generous too.
  tester.view.physicalSize = const Size(1400, 3600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: RuntimeConsoleTable(
          controller: controller,
          platformOverride: platform,
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  group('platform gating', () {
    testWidgets('does not render the table on a phone platform', (
      tester,
    ) async {
      final port = FakeOperationLogPort(opCount: 50);
      final controller = RuntimeConsoleController(log: port);

      await _pumpConsole(tester, controller, platform: TargetPlatform.android);

      expect(find.byKey(const Key('mind.console.unavailable')), findsOneWidget);
      expect(find.byKey(const Key('mind.console.list')), findsNothing);
      // Gated at build time, before ever touching the port.
      expect(port.rangeCalls, isEmpty);
    });

    testWidgets('renders the table on Windows', (tester) async {
      final port = FakeOperationLogPort(opCount: 50);
      final controller = RuntimeConsoleController(log: port);

      await _pumpConsole(tester, controller, platform: TargetPlatform.windows);

      expect(find.byKey(const Key('mind.console.list')), findsOneWidget);
    });

    testWidgets('renders the table on Linux', (tester) async {
      final port = FakeOperationLogPort(opCount: 50);
      final controller = RuntimeConsoleController(log: port);

      await _pumpConsole(tester, controller, platform: TargetPlatform.linux);

      expect(find.byKey(const Key('mind.console.list')), findsOneWidget);
    });
  });

  group('rendering rows', () {
    testWidgets('shows the seeded ops paged, not all at once', (
      tester,
    ) async {
      final port = FakeOperationLogPort(opCount: 12481);
      final controller = RuntimeConsoleController(log: port, pageSize: 20);

      await _pumpConsole(tester, controller);

      expect(controller.loadedCount, 20);
      expect(port.rangeCalls.single.limit, 20);
    });

    testWidgets('an unverified row looks different from a verified one', (
      tester,
    ) async {
      final port = FakeOperationLogPort(opCount: 20);
      final controller = RuntimeConsoleController(log: port, pageSize: 20);
      await _pumpConsole(tester, controller);
      final unverifiedOp = controller.rows.firstWhere(
        (op) => op.signature == SignatureState.unverified,
      );
      final verifiedOp = controller.rows.firstWhere(
        (op) => op.signature == SignatureState.verified,
      );

      final unverifiedText = tester.widget<Text>(
        find.byKey(Key('mind.console.signature.${unverifiedOp.sequence}')),
      );
      final verifiedText = tester.widget<Text>(
        find.byKey(Key('mind.console.signature.${verifiedOp.sequence}')),
      );

      expect(unverifiedText.data, 'UNVERIFIED');
      expect(verifiedText.data, 'verified');
      expect(unverifiedText.style?.color, isNot(verifiedText.style?.color));
    });

    testWidgets('an unsigned row is distinct from both verified and unverified', (
      tester,
    ) async {
      final port = FakeOperationLogPort(opCount: 20);
      final controller = RuntimeConsoleController(log: port, pageSize: 20);
      await _pumpConsole(tester, controller);
      final unsignedOp = controller.rows.firstWhere(
        (op) => op.signature == SignatureState.unsigned,
      );

      final unsignedText = tester.widget<Text>(
        find.byKey(Key('mind.console.signature.${unsignedOp.sequence}')),
      );

      expect(unsignedText.data, 'UNSIGNED');
    });

    testWidgets('each of the seven cited op types renders a distinct label', (
      tester,
    ) async {
      final port = FakeOperationLogPort(opCount: 40);
      final controller = RuntimeConsoleController(log: port, pageSize: 40);
      await _pumpConsole(tester, controller);

      const citedKinds = [
        MindOpKind.automation,
        MindOpKind.scan,
        MindOpKind.merge,
        MindOpKind.inference,
        MindOpKind.voice,
        MindOpKind.revoke,
        MindOpKind.import,
      ];
      final labels = <String>{};
      for (final kind in citedKinds) {
        final op = controller.rows.firstWhere((op) => op.kind == kind);
        final text = tester.widget<Text>(
          find.byKey(Key('mind.console.type.${op.sequence}')),
        );
        labels.add(text.data!);
      }
      expect(labels.length, citedKinds.length, reason: 'every kind renders a distinct label');
    });
  });

  group('sorting', () {
    testWidgets('tapping the Op header sorts by sequence', (tester) async {
      final port = FakeOperationLogPort(opCount: 50);
      final controller = RuntimeConsoleController(log: port, pageSize: 50);
      await _pumpConsole(tester, controller);
      expect(controller.sortField, RuntimeConsoleSortField.sequence);
      expect(controller.sortDirection, RuntimeConsoleSortDirection.descending);

      await tester.tap(find.text('Op'));
      await tester.pump();

      expect(controller.sortDirection, RuntimeConsoleSortDirection.ascending);
    });

    testWidgets('tapping the Device header sorts by device', (tester) async {
      final port = FakeOperationLogPort(opCount: 50);
      final controller = RuntimeConsoleController(log: port, pageSize: 50);
      await _pumpConsole(tester, controller);

      await tester.tap(find.text('Device'));
      await tester.pump();

      expect(controller.sortField, RuntimeConsoleSortField.device);
    });
  });

  group('per-row actions', () {
    testWidgets('tapping the verify icon calls verifyRow and updates the label', (
      tester,
    ) async {
      final port = FakeOperationLogPort(opCount: 20);
      final controller = RuntimeConsoleController(log: port, pageSize: 20);
      await _pumpConsole(tester, controller);
      final op = controller.rows.firstWhere(
        (op) => op.signature == SignatureState.verified,
      );
      port.verifyResults[op.sequence] = SignatureState.unverified;

      await tester.tap(find.byKey(Key('mind.console.verify.${op.sequence}')));
      await tester.pumpAndSettle();

      final text = tester.widget<Text>(
        find.byKey(Key('mind.console.signature.${op.sequence}')),
      );
      expect(text.data, 'UNVERIFIED');
    });

    testWidgets('right-clicking a row replays from that op against the port', (
      tester,
    ) async {
      final port = FakeOperationLogPort(opCount: 20);
      final controller = RuntimeConsoleController(log: port, pageSize: 20);
      await _pumpConsole(tester, controller);
      final op = controller.rows[3];
      port.replaySteps[op.sequence] = [0.0, 1.0];

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(Key('mind.console.row.${op.sequence}'))),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await gesture.up();
      await tester.pumpAndSettle();

      expect(port.replayFromCalls, [op.sequence]);
    });

    testWidgets('a running replay renders progress as a percentage, not a spinner', (
      tester,
    ) async {
      final port = FakeOperationLogPort(opCount: 20);
      final controller = RuntimeConsoleController(log: port, pageSize: 20);
      await _pumpConsole(tester, controller);
      final op = controller.rows[0];
      port.replaySteps[op.sequence] = [0.5];

      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(Key('mind.console.row.${op.sequence}'))),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.byKey(Key('mind.console.replay.${op.sequence}')), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);
    });
  });

  group('non-happy: runtime unavailable', () {
    testWidgets('shows an error rather than an empty table when count() fails', (
      tester,
    ) async {
      final port = FakeOperationLogPort(opCount: 20)
        ..countError = StateError('runtime unavailable');
      final controller = RuntimeConsoleController(log: port);

      await _pumpConsole(tester, controller);

      expect(find.byKey(const Key('mind.console.error')), findsOneWidget);
      expect(find.byKey(const Key('mind.console.list')), findsNothing);
    });
  });
}
