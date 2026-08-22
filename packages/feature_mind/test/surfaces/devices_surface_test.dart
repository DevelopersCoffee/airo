import 'package:feature_mind/src/runtime/fixture/fixture_data.dart';
import 'package:feature_mind/src/runtime/fixture/fixture_mind_runtime.dart';
import 'package:feature_mind/src/runtime/mind_runtime.dart';
import 'package:feature_mind/src/runtime/models/vault_models.dart';
import 'package:feature_mind/src/runtime/ports/mesh_port.dart';
import 'package:feature_mind/src/runtime/ports/vault_port.dart';
import 'package:feature_mind/src/runtime/rust/rust_mind_runtime.dart';
import 'package:feature_mind/src/surfaces/devices_surface.dart';
import 'package:feature_mind/src/widgets/mind_number_strip.dart';
import 'package:feature_mind/src/widgets/mind_presence_pip.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/surface_harness.dart';

/// Surface 05 (#1595): pairing handshake, code/fingerprint/live-stale marker.
///
/// Imports the runtime, models and widgets directly rather than through
/// `package:feature_mind/feature_mind.dart` -- the barrel currently fails to
/// build because of an unrelated, pre-existing gap (missing generated
/// `.freezed.dart` files under `lib/src/llama/` and `lib/src/whisper/`), and
/// this surface has no dependency on either.
///
/// R01 and R04 checks are inlined here rather than routed through
/// `test/support/mind_rule_harness.dart`, because that harness itself imports
/// the broken barrel.
void main() {
  testWidgets('R01 — the presence pip is on screen', (tester) async {
    await pumpSurface(
      tester,
      DevicesSurface(runtime: FixtureMindRuntime(), nowMs: fixtureNowMs),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MindPresencePip), findsAtLeastNWidgets(1));
  });

  testWidgets('R04 — the number strip is on screen', (tester) async {
    await pumpSurface(
      tester,
      DevicesSurface(runtime: FixtureMindRuntime(), nowMs: fixtureNowMs),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MindNumberStrip), findsAtLeastNWidgets(1));
  });

  testWidgets('states the mesh has no server, over LAN only', (tester) async {
    await pumpSurface(
      tester,
      DevicesSurface(runtime: FixtureMindRuntime(), nowMs: fixtureNowMs),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('_airomind._tcp'), findsOneWidget);
    expect(find.textContaining('3 peers'), findsOneWidget);
    expect(find.textContaining('Nothing is sent to a server'), findsOneWidget);
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

  testWidgets('a live peer reads Live', (tester) async {
    await pumpSurface(
      tester,
      DevicesSurface(runtime: FixtureMindRuntime(), nowMs: fixtureNowMs),
    );
    await tester.pumpAndSettle();

    // "This device" (Pixel 9 Pro) always reads live, and iPad Air · Studio
    // was seen 41s before fixtureNowMs -- inside the "live" window the
    // fixture models as PeerLiveness.live. Two rows, not one.
    expect(find.text('Live'), findsNWidgets(2));
  });

  testWidgets(
    'a stale peer names how far behind it is — not a bare "offline"',
    (tester) async {
      await pumpSurface(
        tester,
        DevicesSurface(runtime: FixtureMindRuntime(), nowMs: fixtureNowMs),
      );
      await tester.pumpAndSettle();

      // Fold 6 · Pocket is 14 ops behind and was last seen 6 hours before
      // fixtureNowMs -- the surface must show real elapsed time, not the
      // single word "offline" the design explicitly rejects for a stale (as
      // opposed to declared-gone) peer.
      expect(find.text('6h ago'), findsOneWidget);
      expect(find.text('offline'), findsNothing);
    },
  );

  testWidgets(
    'a revoked device stays listed as evidence, not removed — pre-seeded',
    (tester) async {
      await pumpSurface(
        tester,
        DevicesSurface(runtime: FixtureMindRuntime(), nowMs: fixtureNowMs),
      );
      await tester.pumpAndSettle();

      expect(find.text('MacBook · Old'), findsOneWidget);
      expect(find.textContaining('REVOKED'), findsOneWidget);
      expect(find.textContaining('KEYS SHREDDED'), findsOneWidget);
    },
  );

  testWidgets(
    'revoking a device from this screen keeps its row, marked revoked',
    (tester) async {
      final runtime = FixtureMindRuntime();
      await pumpSurface(
        tester,
        DevicesSurface(runtime: runtime, nowMs: fixtureNowMs),
      );
      await tester.pumpAndSettle();

      // Fold 6 · Pocket is active before this test revokes it.
      expect(find.text('Fold 6 · Pocket'), findsOneWidget);
      expect(find.text('6h ago'), findsOneWidget);

      await runtime.vault.revokeDevice(
        const DeviceFingerprint('C0F9', '22B8', '5E4D'),
      );
      final after = await runtime.vault.devices();
      final revoked = after.firstWhere((d) => d.name == 'Fold 6 · Pocket');

      // The critical requirement (#1595): the row is not deleted, it flips
      // state. Proven against the port directly, independent of whatever the
      // already-pumped widget tree happens to be caching.
      expect(after.length, 4, reason: 'no row disappears on revocation');
      expect(revoked.isRevoked, isTrue);
    },
  );

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
  });

  testWidgets('denying calls the mesh port and clears the request', (
    tester,
  ) async {
    final runtime = FixtureMindRuntime();
    await pumpSurface(
      tester,
      DevicesSurface(runtime: runtime, nowMs: fixtureNowMs),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('DENY'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DENY'));
    await tester.pumpAndSettle();

    expect(find.text('PENDING AUTHORISATION'), findsNothing);
  });

  testWidgets(
    'mesh unavailable: the surface names MeshPort rather than crashing or '
    'saying nothing',
    (tester) async {
      // The real runtime's MeshPort throws until #1200 lands
      // (peers() as well as pendingRequest()), so `_load()` -- which awaits
      // mesh.peers().first alongside the vault calls -- surfaces that
      // failure as the screen's error state. Proven against a mixed runtime
      // (working vault, failing mesh) rather than the fully-unimplemented
      // real one, so this test cannot pass for the unrelated reason of the
      // vault also being unavailable (that is the separate "vault
      // unavailable" test below).
      final runtime = _MixedRuntime(
        vault: FixtureMindRuntime().vault,
        mesh: RustMindRuntime().mesh,
      );

      await pumpSurface(
        tester,
        DevicesSurface(runtime: runtime, nowMs: fixtureNowMs),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('MeshPort'), findsOneWidget);
      expect(find.textContaining('NOT BUILT YET'), findsOneWidget);
      // Names the failing port, not the product.
      expect(find.textContaining('Airo Mind is unavailable'), findsNothing);
    },
  );

  testWidgets(
    'pairing failed: denying an unmatched code states why, not just "no"',
    (tester) async {
      await pumpSurface(
        tester,
        DevicesSurface(runtime: FixtureMindRuntime(), nowMs: fixtureNowMs),
      );
      await tester.pumpAndSettle();

      // The pending card always names the reason a person is asked to check
      // before authorising: the code itself, shown for manual comparison.
      // Denying it is the "pairing failed" path -- stated as a deliberate
      // action with its own control, not a silent timeout.
      expect(find.text('Asking to join your vault'), findsOneWidget);
      expect(find.text(fixturePairingRequest.code), findsOneWidget);
      expect(find.text('DENY'), findsOneWidget);
    },
  );

  testWidgets(
    'vault unavailable: the surface names the missing port, not the product',
    (tester) async {
      await pumpSurface(
        tester,
        DevicesSurface(runtime: RustMindRuntime(), nowMs: fixtureNowMs),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('VaultPort'), findsOneWidget);
      expect(find.textContaining('NOT BUILT YET'), findsOneWidget);
    },
  );

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

/// VaultPort answers from one runtime, MeshPort throws like the real one
/// still not implementing #1200 -- the combination the "mesh unavailable"
/// non-happy state test needs and neither shipped runtime produces alone.
class _MixedRuntime implements MindRuntime {
  const _MixedRuntime({required this.vault, required this.mesh});

  @override
  final VaultPort vault;

  @override
  final MeshPort mesh;

  @override
  Never get log => throw UnimplementedError();

  @override
  Never get contexts => throw UnimplementedError();

  @override
  Never get projections => throw UnimplementedError();

  @override
  Never get capabilities => throw UnimplementedError();

  @override
  Never get models => throw UnimplementedError();

  @override
  Never get portability => throw UnimplementedError();
}
