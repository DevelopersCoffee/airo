import 'package:feature_mind/feature_mind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('value semantics', () {
    test('two ops with the same fields are equal', () {
      const a = MindOp(
        sequence: 12481,
        kind: MindOpKind.automation,
        title: 'Ibuprofen 400 mg logged',
        contextId: 'kneesurgery2026',
        deviceName: 'Pixel 9 Pro',
        signature: SignatureState.verified,
        recordedAtMs: 1785827524000,
      );
      const b = MindOp(
        sequence: 12481,
        kind: MindOpKind.automation,
        title: 'Ibuprofen 400 mg logged',
        contextId: 'kneesurgery2026',
        deviceName: 'Pixel 9 Pro',
        signature: SignatureState.verified,
        recordedAtMs: 1785827524000,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('an op that failed verification is not equal to one that passed', () {
      const verified = MindOp(
        sequence: 1,
        kind: MindOpKind.note,
        title: 't',
        contextId: 'c',
        deviceName: 'd',
        signature: SignatureState.verified,
        recordedAtMs: 0,
      );
      final unverified = verified.copyWith(
        signature: SignatureState.unverified,
      );

      expect(verified, isNot(equals(unverified)));
    });
  });

  test('a context reports its own item count', () {
    const context = MindContext(
      id: 'kneesurgery2026',
      label: '#KneeSurgery2026',
      itemCount: 38,
      opCount: 1204,
      openedAtMs: 0,
      safetyClass: CapabilitySafetyClass.health,
    );

    expect(context.itemCount, 38);
    expect(context.label, startsWith('#'));
  });

  test('a peer that is behind reports how far, not just that it is', () {
    const peer = MindPeer(
      deviceName: 'iPad Air',
      fingerprint: DeviceFingerprint('81DD', '4A05', '7712'),
      liveness: PeerLiveness.stale,
      opsBehind: 14,
      lastSeenMs: 0,
    );

    expect(peer.opsBehind, 14);
    expect(peer.fingerprint.toString(), '81DD · 4A05 · 7712');
  });

  test('a context link is undirected', () {
    // Linking A to B links B to A. If these compared unequal the hypergraph
    // would hold both edges and the survival preview would double-count.
    const forward = ContextLink('a', 'b');
    const backward = ContextLink('b', 'a');

    expect(forward, equals(backward));
    expect(forward.hashCode, equals(backward.hashCode));
  });

  test('a revoked device still reports its name and key', () {
    const revoked = MindDevice(
      name: 'MacBook · Old',
      fingerprint: DeviceFingerprint('A731', '0C4E', '9982'),
      isThisDevice: false,
      revokedAtMs: 1785827524000,
    );

    expect(revoked.isRevoked, isTrue);
    expect(revoked.name, 'MacBook · Old');
  });

  test('a package plan totals its content classes', () {
    const plan = RecoveryPackagePlan(
      selectedContextIds: ['kneesurgery2026'],
      breakdown: [
        ContentClassSize('Scans', 1200000000),
        ContentClassSize('Audio', 780000000),
        ContentClassSize('Log', 420000000),
      ],
      fileName: 'airo-2026-08-01.airobackup',
    );

    expect(plan.totalBytes, 2400000000);
  });

  test('a model with no benchmark reports none rather than a guess', () {
    const model = MindModel(
      id: 'phi_4_mini',
      name: 'Phi-4 mini · 3.8B',
      sizeBytes: 2600000000,
      residency: ModelResidency.available,
    );

    expect(model.bench, isNull);
    expect(model.heldBy, isEmpty);
  });

  test('a projection carries the progress its rebuilding state needs', () {
    const rebuilding = ProjectionState(
      kind: ProjectionKind.search,
      status: ProjectionStatus.rebuilding,
      lastRebuildMs: 3100,
      opsProcessed: 6240,
      opsTotal: 12481,
    );

    expect(rebuilding.opsProcessed, lessThan(rebuilding.opsTotal));
    expect(rebuilding.lastRebuildMs, 3100);
  });
}
