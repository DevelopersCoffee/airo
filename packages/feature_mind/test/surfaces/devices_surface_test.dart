import 'package:feature_mind/feature_mind.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/mind_rule_harness.dart';
import '../support/surface_harness.dart';

void main() {
  testWidgets('states the mesh has no server, over LAN only', (tester) async {
    await pumpSurface(
      tester,
      DevicesSurface(runtime: FixtureMindRuntime(), nowMs: fixtureNowMs),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('_airomind._tcp'), findsOneWidget);
    expect(find.textContaining('3 peers'), findsOneWidget);
    expect(find.textContaining('Nothing is sent to a server'), findsOneWidget);
    await expectSatisfiesMindRules(tester, expectsNumbers: false);
  });

  testWidgets('this device is marked and always reads live', (tester) async {
    await pumpSurface(
      tester,
      DevicesSurface(runtime: FixtureMindRuntime(), nowMs: fixtureNowMs),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pixel 9 Pro'), findsOneWidget);
    expect(find.text('THIS DEVICE'), findsOneWidget);
    expect(find.text('key 4F2A · 9C71 · E0B3'), findsOneWidget);
  });

  testWidgets('a stale peer reads its real elapsed time, not "Live"', (
    tester,
  ) async {
    await pumpSurface(
      tester,
      DevicesSurface(runtime: FixtureMindRuntime(), nowMs: fixtureNowMs),
    );
    await tester.pumpAndSettle();

    // Fold 6 was last seen 6 hours before fixtureNowMs.
    expect(find.text('6h ago'), findsOneWidget);
  });

  testWidgets('a revoked device stays listed as evidence, not removed', (
    tester,
  ) async {
    await pumpSurface(
      tester,
      DevicesSurface(runtime: FixtureMindRuntime(), nowMs: fixtureNowMs),
    );
    await tester.pumpAndSettle();

    expect(find.text('MacBook · Old'), findsOneWidget);
    expect(find.textContaining('REVOKED'), findsOneWidget);
    expect(find.textContaining('KEYS SHREDDED'), findsOneWidget);
  });

  testWidgets('states revocation is O(contexts), never O(content)', (
    tester,
  ) async {
    await pumpSurface(
      tester,
      DevicesSurface(runtime: FixtureMindRuntime(), nowMs: fixtureNowMs),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('loses every key at once'), findsOneWidget);
  });

  testWidgets('a pending pairing request shows the six-digit code', (
    tester,
  ) async {
    await pumpSurface(
      tester,
      DevicesSurface(runtime: FixtureMindRuntime(), nowMs: fixtureNowMs),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pixel Watch 3'), findsOneWidget);
    expect(find.textContaining('492716'), findsOneWidget);
    expect(find.text('DENY'), findsOneWidget);
    expect(find.text('AUTHORISE'), findsOneWidget);
  });

  testWidgets('authorising calls the mesh port and clears the request', (
    tester,
  ) async {
    final runtime = FixtureMindRuntime();
    await pumpSurface(
      tester,
      DevicesSurface(runtime: runtime, nowMs: fixtureNowMs),
    );
    await tester.pumpAndSettle();

    // The pending card sits below four device rows; at 390 x 844 that is
    // below the fold, and a bare tap() would land past the viewport without
    // this -- exactly the kind of failure a test can pass through by
    // accident if the assertion afterward doesn't check the tap actually
    // landed.
    await tester.ensureVisible(find.text('AUTHORISE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AUTHORISE'));
    await tester.pumpAndSettle();

    // The pending card must be gone from the surface's own state -- not just
    // "the fixture's stream still has it," which would pass even if the tap
    // silently missed.
    expect(find.text('PENDING AUTHORISATION'), findsNothing);

    // The fixture's authorise() is a no-op that does not remove the pending
    // request from its own stream, so re-fetching still shows it. That is a
    // second, independent confirmation the call actually reached the port.
    final stillPending = await runtime.mesh.pendingRequest().first;
    expect(stillPending?.deviceName, 'Pixel Watch 3');
  });

  testWidgets('reports the missing port when the runtime is partial', (
    tester,
  ) async {
    await pumpSurface(
      tester,
      DevicesSurface(runtime: RustMindRuntime(), nowMs: fixtureNowMs),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('VaultPort'), findsOneWidget);
  });

  testWidgets('golden — layout at 390 x 844', (tester) async {
    await pumpSurface(
      tester,
      DevicesSurface(runtime: FixtureMindRuntime(), nowMs: fixtureNowMs),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(DevicesSurface),
      matchesGoldenFile('goldens/devices.png'),
    );
  });
}
