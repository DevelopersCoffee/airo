import 'dart:async';

import 'package:flutter/foundation.dart';

import '../runtime/models/mesh_models.dart';
import '../runtime/models/portability_models.dart';
import '../runtime/models/vault_models.dart';
import '../runtime/ports/context_port.dart';
import '../runtime/ports/mesh_port.dart';
import '../runtime/ports/portability_port.dart';
import 'backup_envelope_state.dart';
import 'destination_validation.dart';

/// Floor on the sealing phrase's length.
///
/// This is a UX gate against a trivially guessable phrase, not a key
/// derivation policy: the package format's actual cryptography belongs to
/// #1305 / #1211 and is out of scope here -- this flow only carries the
/// phrase through to [PortabilityPort.seal] unmodified.
const int kMinBackupPassphraseLength = 10;

/// Reports free space at a destination, or `null` when it is unknown.
///
/// `null` means "don't block on it" rather than "fail" -- a caller that has
/// not wired a real check should not spuriously refuse every backup. A
/// surface talking to a real transport should return the actual figure.
typedef DestinationSpaceChecker =
    Future<int?> Function(PackageDestination destination, MindPeer? peer);

Future<int?> _unknownSpace(PackageDestination destination, MindPeer? peer) async =>
    null;

/// Drives surface 08's flow: pick contexts, set the phrase, choose a
/// destination, confirm.
///
/// State only moves forward through [advance]; each step validates itself
/// before allowing the next and leaves [BackupEnvelopeState.error] set when
/// it refuses. Moving [back] never discards what was already chosen further
/// along, so returning to fix a context selection does not surprise the
/// destination step.
class BackupEnvelopeController extends ValueNotifier<BackupEnvelopeState> {
  BackupEnvelopeController({
    required this.contexts,
    required this.portability,
    required this.mesh,
    DestinationSpaceChecker? spaceChecker,
  }) : _spaceChecker = spaceChecker ?? _unknownSpace,
       super(const BackupEnvelopeState.initial());

  final ContextPort contexts;
  final PortabilityPort portability;
  final MeshPort mesh;
  final DestinationSpaceChecker _spaceChecker;

  /// Populates the context list to pick from. Call once before the surface
  /// renders its first frame.
  Future<void> loadContexts() async {
    final all = await contexts.all();
    value = value.copyWith(availableContexts: all);
  }

  /// Populates the LAN peer list a "send to a peer" choice offers.
  Future<void> loadPeers() async {
    final peers = await mesh.peers().first;
    value = value.copyWith(availablePeers: peers);
  }

  /// Flips [contextId] in the selection and recomputes the plan -- a size
  /// figure that does not move when a context is unchecked tells the person
  /// their choice did nothing.
  Future<void> toggleContext(String contextId) async {
    final selected = {...value.selectedContextIds};
    if (!selected.remove(contextId)) {
      selected.add(contextId);
    }
    value = value.copyWith(selectedContextIds: selected, clearError: true);
    await _recomputePlan();
  }

  Future<void> _recomputePlan() async {
    if (value.selectedContextIds.isEmpty) {
      value = value.copyWith(clearPlan: true);
      return;
    }
    final plan = await portability.plan(value.selectedContextIds.toList());
    value = value.copyWith(plan: plan);
  }

  void setPassphrase(String passphrase) {
    value = value.copyWith(passphrase: passphrase, clearError: true);
  }

  /// Marks the "lose it and it cannot be opened" warning as read. Must be
  /// called before [advance] will leave [BackupSealStep.setPassphrase] --
  /// the warning is shown before sealing, not after.
  void acknowledgePassphraseWarning() {
    value = value.copyWith(passphraseWarningAcknowledged: true, clearError: true);
  }

  /// Chooses a destination kind, and for [PackageDestination.lanPeer] which
  /// peer. [targetDescriptor] is free text naming the concrete target -- a
  /// peer's advertised name, or a mount/file path for "this device" and
  /// "USB drive" -- and is rejected immediately if it reads as a cloud
  /// endpoint (see [isLocalDestinationTarget]); reachability and space are
  /// checked later, on [advance].
  void selectDestination(
    PackageDestination destination, {
    DeviceFingerprint? peerFingerprint,
    String targetDescriptor = '',
  }) {
    if (!isLocalDestinationTarget(targetDescriptor)) {
      value = value.copyWith(
        error: BackupValidationError.destinationLooksLikeCloud,
        clearDestination: true,
        clearSelectedPeer: true,
      );
      return;
    }
    value = value.copyWith(
      destination: destination,
      selectedPeerFingerprint: peerFingerprint,
      clearSelectedPeer: peerFingerprint == null,
      clearError: true,
    );
  }

  /// Attempts to move to the next step, validating the current one first.
  /// Returns true when it moved; when false, [BackupEnvelopeState.error]
  /// explains why.
  Future<bool> advance() async {
    switch (value.step) {
      case BackupSealStep.selectContexts:
        return _advanceFromContexts();
      case BackupSealStep.setPassphrase:
        return _advanceFromPassphrase();
      case BackupSealStep.chooseDestination:
        return _advanceFromDestination();
      case BackupSealStep.confirm:
        value = value.copyWith(step: BackupSealStep.sealing, clearError: true);
        unawaited(_seal());
        return true;
      case BackupSealStep.sealing:
      case BackupSealStep.sealed:
        return false;
    }
  }

  bool _advanceFromContexts() {
    if (value.selectedContextIds.isEmpty) {
      value = value.copyWith(error: BackupValidationError.noContextsSelected);
      return false;
    }
    value = value.copyWith(step: BackupSealStep.setPassphrase, clearError: true);
    return true;
  }

  bool _advanceFromPassphrase() {
    if (value.passphrase.length < kMinBackupPassphraseLength) {
      value = value.copyWith(error: BackupValidationError.passphraseTooShort);
      return false;
    }
    if (!value.passphraseWarningAcknowledged) {
      value = value.copyWith(
        error: BackupValidationError.passphraseWarningNotAcknowledged,
      );
      return false;
    }
    value = value.copyWith(step: BackupSealStep.chooseDestination, clearError: true);
    return true;
  }

  Future<bool> _advanceFromDestination() async {
    final destination = value.destination;
    if (destination == null) {
      value = value.copyWith(error: BackupValidationError.noDestinationSelected);
      return false;
    }
    if (destination == PackageDestination.lanPeer) {
      final peer = value.selectedPeer;
      if (peer == null || peer.liveness != PeerLiveness.live) {
        value = value.copyWith(error: BackupValidationError.destinationUnreachable);
        return false;
      }
    }
    final needed = value.plan?.totalBytes ?? 0;
    final available = await _spaceChecker(destination, value.selectedPeer);
    if (available != null && available < needed) {
      value = value.copyWith(error: BackupValidationError.insufficientSpace);
      return false;
    }
    value = value.copyWith(step: BackupSealStep.confirm, clearError: true);
    return true;
  }

  Future<void> _seal() async {
    final plan = value.plan;
    final destination = value.destination;
    if (plan == null || destination == null) {
      value = value.copyWith(error: BackupValidationError.noDestinationSelected);
      return;
    }
    await for (final progress in portability.seal(
      plan: plan,
      passphrase: value.passphrase,
      destination: destination,
    )) {
      value = value.copyWith(sealProgress: progress);
    }
    value = value.copyWith(step: BackupSealStep.sealed);
  }

  /// Moves one step back without discarding what was chosen there.
  void back() {
    final previous = switch (value.step) {
      BackupSealStep.selectContexts => BackupSealStep.selectContexts,
      BackupSealStep.setPassphrase => BackupSealStep.selectContexts,
      BackupSealStep.chooseDestination => BackupSealStep.setPassphrase,
      BackupSealStep.confirm => BackupSealStep.chooseDestination,
      BackupSealStep.sealing => BackupSealStep.confirm,
      BackupSealStep.sealed => BackupSealStep.sealed,
    };
    value = value.copyWith(step: previous, clearError: true);
  }
}
