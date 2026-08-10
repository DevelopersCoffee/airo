import 'dart:async';

import 'package:feature_mind/src/portability/backup_envelope_controller.dart';
import 'package:feature_mind/src/portability/backup_envelope_state.dart';
import 'package:feature_mind/src/runtime/models/context_models.dart';
import 'package:feature_mind/src/runtime/models/capability_models.dart';
import 'package:feature_mind/src/runtime/models/mesh_models.dart';
import 'package:feature_mind/src/runtime/models/portability_models.dart';
import 'package:feature_mind/src/runtime/models/vault_models.dart';
import 'package:feature_mind/src/runtime/ports/context_port.dart';
import 'package:feature_mind/src/runtime/ports/mesh_port.dart';
import 'package:feature_mind/src/runtime/ports/portability_port.dart';
import 'package:flutter_test/flutter_test.dart';

const _kneeId = 'kneesurgery2026';
const _taxId = 'q3taxfiling';

MindContext _context(String id, int itemCount) => MindContext(
  id: id,
  label: '#$id',
  itemCount: itemCount,
  opCount: itemCount * 10,
  openedAtMs: 0,
  safetyClass: CapabilitySafetyClass.general,
);

const _perContextBytes = <String, int>{_kneeId: 1000, _taxId: 500};

class FakeContextPort implements ContextPort {
  List<MindContext> contexts = [_context(_kneeId, 38), _context(_taxId, 52)];

  @override
  Future<List<MindContext>> all() async => contexts;

  @override
  Future<MindContext?> byId(String id) async {
    for (final c in contexts) {
      if (c.id == id) return c;
    }
    return null;
  }

  @override
  Future<List<ContextLink>> linksFor(String contextId) async => const [];

  @override
  Future<MindContext> create({required String label}) => throw UnimplementedError();

  @override
  Future<void> link(String fromId, String toId) => throw UnimplementedError();

  @override
  Future<void> unlink(String fromId, String toId) => throw UnimplementedError();

  @override
  Future<List<String>> survivorsIfDestroyed(String contextId) async => const [];
}

class FakePortabilityPort implements PortabilityPort {
  int planCalls = 0;
  bool failSeal = false;

  @override
  Future<RecoveryPackagePlan> plan(List<String> contextIds) async {
    planCalls++;
    var total = 0;
    for (final id in contextIds) {
      total += _perContextBytes[id] ?? 0;
    }
    return RecoveryPackagePlan(
      selectedContextIds: List.unmodifiable(contextIds),
      breakdown: [ContentClassSize('Scans', total)],
      fileName: 'test.airobackup',
    );
  }

  @override
  Stream<({int total, int written})> seal({
    required RecoveryPackagePlan plan,
    required String passphrase,
    required PackageDestination destination,
  }) async* {
    if (failSeal) {
      throw StateError('destination unreachable mid-seal');
    }
    final total = plan.totalBytes;
    yield (written: total, total: total);
  }
}

class FakeMeshPort implements MeshPort {
  List<MindPeer> peerList = const [];

  @override
  Stream<List<MindPeer>> peers() => Stream.value(peerList);

  @override
  Stream<PairingRequest?> pendingRequest() => Stream.value(null);

  @override
  Future<void> authorise(PairingRequest request) async {}

  @override
  Future<void> deny(PairingRequest request) async {}

  @override
  Future<int> push(DeviceFingerprint peer) async => 0;
}

const _livePeer = MindPeer(
  deviceName: 'Kitchen Tablet',
  fingerprint: DeviceFingerprint('a', 'b', 'c'),
  liveness: PeerLiveness.live,
  opsBehind: 0,
  lastSeenMs: 0,
);

const _offlinePeer = MindPeer(
  deviceName: 'Old Laptop',
  fingerprint: DeviceFingerprint('d', 'e', 'f'),
  liveness: PeerLiveness.offline,
  opsBehind: 12,
  lastSeenMs: 0,
);

void main() {
  late FakeContextPort contexts;
  late FakePortabilityPort portability;
  late FakeMeshPort mesh;
  late BackupEnvelopeController controller;

  setUp(() {
    contexts = FakeContextPort();
    portability = FakePortabilityPort();
    mesh = FakeMeshPort()..peerList = [_livePeer, _offlinePeer];
    controller = BackupEnvelopeController(
      contexts: contexts,
      portability: portability,
      mesh: mesh,
    );
  });

  group('content-class size breakdown', () {
    test('is null before any context is selected', () async {
      await controller.loadContexts();
      expect(controller.value.plan, isNull);
    });

    test('recomputes when a context is toggled on', () async {
      await controller.loadContexts();
      await controller.toggleContext(_kneeId);
      expect(controller.value.plan!.totalBytes, 1000);
    });

    test('recomputes down when a context is toggled back off', () async {
      await controller.loadContexts();
      await controller.toggleContext(_kneeId);
      await controller.toggleContext(_taxId);
      expect(controller.value.plan!.totalBytes, 1500);

      await controller.toggleContext(_kneeId);
      expect(
        controller.value.plan!.totalBytes,
        500,
        reason: 'unchecking a context must actually exclude it',
      );
    });

    test('clears the plan when the last context is unchecked', () async {
      await controller.loadContexts();
      await controller.toggleContext(_kneeId);
      await controller.toggleContext(_kneeId);
      expect(controller.value.plan, isNull);
    });
  });

  group('non-happy: no contexts selected', () {
    test('advance refuses and reports the reason', () async {
      await controller.loadContexts();
      final moved = await controller.advance();
      expect(moved, isFalse);
      expect(controller.value.error, BackupValidationError.noContextsSelected);
      expect(controller.value.step, BackupSealStep.selectContexts);
    });
  });

  group('passphrase gate', () {
    Future<void> selectAContext() async {
      await controller.loadContexts();
      await controller.toggleContext(_kneeId);
      await controller.advance();
    }

    test('rejects a phrase under the minimum length', () async {
      await selectAContext();
      controller.setPassphrase('short');
      final moved = await controller.advance();
      expect(moved, isFalse);
      expect(controller.value.error, BackupValidationError.passphraseTooShort);
    });

    test('rejects a long-enough phrase whose warning was not acknowledged', () async {
      await selectAContext();
      controller.setPassphrase('a very long passphrase indeed');
      final moved = await controller.advance();
      expect(moved, isFalse);
      expect(
        controller.value.error,
        BackupValidationError.passphraseWarningNotAcknowledged,
      );
    });

    test('advances once the phrase is long enough and the warning is acknowledged', () async {
      await selectAContext();
      controller.setPassphrase('a very long passphrase indeed');
      controller.acknowledgePassphraseWarning();
      final moved = await controller.advance();
      expect(moved, isTrue);
      expect(controller.value.step, BackupSealStep.chooseDestination);
    });
  });

  group('destination validity', () {
    Future<void> reachDestinationStep() async {
      await controller.loadContexts();
      await controller.loadPeers();
      await controller.toggleContext(_kneeId);
      await controller.advance();
      controller.setPassphrase('a very long passphrase indeed');
      controller.acknowledgePassphraseWarning();
      await controller.advance();
    }

    test('refuses to advance with no destination chosen', () async {
      await reachDestinationStep();
      final moved = await controller.advance();
      expect(moved, isFalse);
      expect(controller.value.error, BackupValidationError.noDestinationSelected);
    });

    test('this device and USB drive are accepted', () async {
      await reachDestinationStep();
      controller.selectDestination(PackageDestination.thisDevice);
      final moved = await controller.advance();
      expect(moved, isTrue);
      expect(controller.value.step, BackupSealStep.confirm);
    });

    test('a live LAN peer is accepted', () async {
      await reachDestinationStep();
      controller.selectDestination(
        PackageDestination.lanPeer,
        peerFingerprint: _livePeer.fingerprint,
      );
      final moved = await controller.advance();
      expect(moved, isTrue);
    });

    test('an offline LAN peer is rejected as unreachable', () async {
      await reachDestinationStep();
      controller.selectDestination(
        PackageDestination.lanPeer,
        peerFingerprint: _offlinePeer.fingerprint,
      );
      final moved = await controller.advance();
      expect(moved, isFalse);
      expect(controller.value.error, BackupValidationError.destinationUnreachable);
    });

    test('lanPeer with no peer chosen is rejected as unreachable', () async {
      await reachDestinationStep();
      controller.selectDestination(PackageDestination.lanPeer);
      final moved = await controller.advance();
      expect(moved, isFalse);
      expect(controller.value.error, BackupValidationError.destinationUnreachable);
    });

    test('a target descriptor that looks like a cloud endpoint is rejected immediately', () async {
      await reachDestinationStep();
      controller.selectDestination(
        PackageDestination.usbDrive,
        targetDescriptor: r'\\backup\drive.google.com\share',
      );
      expect(
        controller.value.error,
        BackupValidationError.destinationLooksLikeCloud,
      );
      expect(controller.value.destination, isNull);
    });

    test('an https-looking peer name is rejected immediately', () async {
      await reachDestinationStep();
      controller.selectDestination(
        PackageDestination.lanPeer,
        peerFingerprint: _livePeer.fingerprint,
        targetDescriptor: 'https://not-actually-lan.example.com',
      );
      expect(
        controller.value.error,
        BackupValidationError.destinationLooksLikeCloud,
      );
    });

    test('insufficient space at the destination is rejected', () async {
      await reachDestinationStep();
      final tightController = BackupEnvelopeController(
        contexts: contexts,
        portability: portability,
        mesh: mesh,
        spaceChecker: (destination, peer) async => 10,
      );
      await tightController.loadContexts();
      await tightController.toggleContext(_kneeId);
      await tightController.advance();
      tightController.setPassphrase('a very long passphrase indeed');
      tightController.acknowledgePassphraseWarning();
      await tightController.advance();
      tightController.selectDestination(PackageDestination.thisDevice);

      final moved = await tightController.advance();
      expect(moved, isFalse);
      expect(tightController.value.error, BackupValidationError.insufficientSpace);
    });

    test('an unknown space (null) does not block advancing', () async {
      await reachDestinationStep();
      controller.selectDestination(PackageDestination.thisDevice);
      final moved = await controller.advance();
      expect(moved, isTrue);
    });
  });

  group('envelope sealing flow state machine', () {
    Future<void> reachConfirmStep() async {
      await controller.loadContexts();
      await controller.loadPeers();
      await controller.toggleContext(_kneeId);
      await controller.advance();
      controller.setPassphrase('a very long passphrase indeed');
      controller.acknowledgePassphraseWarning();
      await controller.advance();
      controller.selectDestination(PackageDestination.thisDevice);
      await controller.advance();
    }

    test('walks contexts -> passphrase -> destination -> confirm in order', () async {
      expect(controller.value.step, BackupSealStep.selectContexts);
      await reachConfirmStep();
      expect(controller.value.step, BackupSealStep.confirm);
    });

    test('confirm starts sealing and eventually reaches sealed', () async {
      await reachConfirmStep();
      await controller.advance();
      expect(controller.value.step, BackupSealStep.sealing);

      await pumpEventQueue();
      expect(controller.value.step, BackupSealStep.sealed);
      expect(controller.value.isSealed, isTrue);
      expect(controller.value.sealProgress!.written, controller.value.sealProgress!.total);
    });

    test('sealing and sealed refuse further advance calls', () async {
      await reachConfirmStep();
      await controller.advance();
      expect(await controller.advance(), isFalse);
      await pumpEventQueue();
      expect(await controller.advance(), isFalse);
    });

    test('back from destination returns to passphrase without losing it', () async {
      await controller.loadContexts();
      await controller.toggleContext(_kneeId);
      await controller.advance();
      controller.setPassphrase('a very long passphrase indeed');
      controller.acknowledgePassphraseWarning();
      await controller.advance();
      expect(controller.value.step, BackupSealStep.chooseDestination);

      controller.back();
      expect(controller.value.step, BackupSealStep.setPassphrase);
      expect(controller.value.passphrase, 'a very long passphrase indeed');
      expect(controller.value.passphraseWarningAcknowledged, isTrue);
    });

    test('back from contexts step is a no-op', () async {
      controller.back();
      expect(controller.value.step, BackupSealStep.selectContexts);
    });
  });
}
