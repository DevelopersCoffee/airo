import 'package:flutter/foundation.dart';

import 'vault_models.dart';

/// Whether a peer is reachable right now.
///
/// `stale` is a peer we know and have not heard from. `offline` is one that
/// declared itself gone. The devices surface renders them differently because
/// only one of them is a problem.
enum PeerLiveness { live, stale, offline }

/// A peer on the local network.
@immutable
class MindPeer {
  const MindPeer({
    required this.deviceName,
    required this.fingerprint,
    required this.liveness,
    required this.opsBehind,
    required this.lastSeenMs,
  });

  final String deviceName;
  final DeviceFingerprint fingerprint;
  final PeerLiveness liveness;

  /// How many ops this peer has not yet received. Zero means in sync.
  ///
  /// Surfaces show this number rather than the word "syncing", because a
  /// number tells a person whether to wait.
  final int opsBehind;
  final int lastSeenMs;

  @override
  bool operator ==(Object other) =>
      other is MindPeer &&
      other.deviceName == deviceName &&
      other.fingerprint == fingerprint &&
      other.liveness == liveness &&
      other.opsBehind == opsBehind &&
      other.lastSeenMs == lastSeenMs;

  @override
  int get hashCode =>
      Object.hash(deviceName, fingerprint, liveness, opsBehind, lastSeenMs);
}

/// A device asking to join the vault, with the code the two screens compare.
@immutable
class PairingRequest {
  const PairingRequest({
    required this.deviceName,
    required this.code,
    required this.requestedAtMs,
  });

  final String deviceName;

  /// Six digits. Shown on both devices; a person authorises by matching them.
  final String code;
  final int requestedAtMs;

  @override
  bool operator ==(Object other) =>
      other is PairingRequest &&
      other.deviceName == deviceName &&
      other.code == code &&
      other.requestedAtMs == requestedAtMs;

  @override
  int get hashCode => Object.hash(deviceName, code, requestedAtMs);
}
