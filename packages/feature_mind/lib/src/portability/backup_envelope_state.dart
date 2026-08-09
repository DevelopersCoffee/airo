import 'package:flutter/foundation.dart';

import '../runtime/models/context_models.dart';
import '../runtime/models/mesh_models.dart';
import '../runtime/models/portability_models.dart';
import '../runtime/models/vault_models.dart';

/// Steps of the envelope-sealing flow, in order.
///
/// Surface 08's own words: "pick contexts, set the phrase, choose a
/// destination on your own network." [advance] is the only way forward;
/// [BackupEnvelopeState.error] explains why it refused when it does.
enum BackupSealStep {
  selectContexts,
  setPassphrase,
  chooseDestination,
  confirm,
  sealing,
  sealed,
}

/// Why the flow refused to advance. A surface renders this next to the
/// control that caused it, not as a generic toast -- someone who unchecked
/// every context should see why "Next" is dead exactly where they are
/// looking.
enum BackupValidationError {
  noContextsSelected,
  passphraseTooShort,
  passphraseWarningNotAcknowledged,
  noDestinationSelected,
  destinationUnreachable,
  insufficientSpace,

  /// The free text naming the destination (a peer name, a mount/file path)
  /// matched one of [cloudDestinationMarkers]. [PackageDestination] has no
  /// cloud variant to pick in the first place; this is the second gate, for
  /// when the concrete target is spoofed, mistyped, or resolves elsewhere.
  destinationLooksLikeCloud,
}

/// Snapshot of the envelope-sealing flow at a point in time.
@immutable
class BackupEnvelopeState {
  const BackupEnvelopeState({
    required this.step,
    required this.availableContexts,
    required this.selectedContextIds,
    required this.availablePeers,
    required this.plan,
    required this.passphrase,
    required this.passphraseWarningAcknowledged,
    required this.destination,
    required this.selectedPeerFingerprint,
    required this.error,
    required this.sealProgress,
  });

  const BackupEnvelopeState.initial()
    : step = BackupSealStep.selectContexts,
      availableContexts = const [],
      selectedContextIds = const {},
      availablePeers = const [],
      plan = null,
      passphrase = '',
      passphraseWarningAcknowledged = false,
      destination = null,
      selectedPeerFingerprint = null,
      error = null,
      sealProgress = null;

  final BackupSealStep step;
  final List<MindContext> availableContexts;
  final Set<String> selectedContextIds;
  final List<MindPeer> availablePeers;

  /// Recomputed on every selection change. Null before the first context is
  /// chosen -- there is nothing to plan yet.
  final RecoveryPackagePlan? plan;
  final String passphrase;

  /// The design's warning ("lose it and the package cannot be opened, not
  /// by you and not by us, and there is no reset") must be shown and
  /// acknowledged before [BackupSealStep.setPassphrase] can advance --
  /// "shown before sealing, not after."
  final bool passphraseWarningAcknowledged;
  final PackageDestination? destination;
  final DeviceFingerprint? selectedPeerFingerprint;
  final BackupValidationError? error;
  final ({int written, int total})? sealProgress;

  bool get isSealed => step == BackupSealStep.sealed;

  MindPeer? get selectedPeer {
    final fingerprint = selectedPeerFingerprint;
    if (fingerprint == null) return null;
    for (final peer in availablePeers) {
      if (peer.fingerprint == fingerprint) return peer;
    }
    return null;
  }

  BackupEnvelopeState copyWith({
    BackupSealStep? step,
    List<MindContext>? availableContexts,
    Set<String>? selectedContextIds,
    List<MindPeer>? availablePeers,
    RecoveryPackagePlan? plan,
    bool clearPlan = false,
    String? passphrase,
    bool? passphraseWarningAcknowledged,
    PackageDestination? destination,
    bool clearDestination = false,
    DeviceFingerprint? selectedPeerFingerprint,
    bool clearSelectedPeer = false,
    BackupValidationError? error,
    bool clearError = false,
    ({int written, int total})? sealProgress,
  }) {
    return BackupEnvelopeState(
      step: step ?? this.step,
      availableContexts: availableContexts ?? this.availableContexts,
      selectedContextIds: selectedContextIds ?? this.selectedContextIds,
      availablePeers: availablePeers ?? this.availablePeers,
      plan: clearPlan ? null : (plan ?? this.plan),
      passphrase: passphrase ?? this.passphrase,
      passphraseWarningAcknowledged:
          passphraseWarningAcknowledged ?? this.passphraseWarningAcknowledged,
      destination: clearDestination ? null : (destination ?? this.destination),
      selectedPeerFingerprint: clearSelectedPeer
          ? null
          : (selectedPeerFingerprint ?? this.selectedPeerFingerprint),
      error: clearError ? null : (error ?? this.error),
      sealProgress: sealProgress ?? this.sealProgress,
    );
  }
}
