import 'package:flutter/foundation.dart';

/// A device key, shown to a person three groups at a time.
///
/// Grouped because a person compares these by eye during pairing, and an
/// unbroken hex run is the one format they cannot compare reliably.
@immutable
class DeviceFingerprint {
  const DeviceFingerprint(this.a, this.b, this.c);

  final String a;
  final String b;
  final String c;

  @override
  String toString() => '$a · $b · $c';

  @override
  bool operator ==(Object other) =>
      other is DeviceFingerprint &&
      other.a == a &&
      other.b == b &&
      other.c == c;

  @override
  int get hashCode => Object.hash(a, b, c);
}

/// A device that is, or was, authorised against this vault.
///
/// Revoked devices stay in the list. They are evidence, and a device that
/// vanishes on revocation cannot be distinguished from one that never existed.
@immutable
class MindDevice {
  const MindDevice({
    required this.name,
    required this.fingerprint,
    required this.isThisDevice,
    required this.revokedAtMs,
  });

  final String name;
  final DeviceFingerprint fingerprint;
  final bool isThisDevice;

  /// Null while authorised.
  final int? revokedAtMs;

  bool get isRevoked => revokedAtMs != null;

  @override
  bool operator ==(Object other) =>
      other is MindDevice &&
      other.name == name &&
      other.fingerprint == fingerprint &&
      other.isThisDevice == isThisDevice &&
      other.revokedAtMs == revokedAtMs;

  @override
  int get hashCode => Object.hash(name, fingerprint, isThisDevice, revokedAtMs);
}

/// The vault's state as a surface needs to render it.
///
/// [revocationEpoch] is monotonic; a peer presenting a lower epoch is stale and
/// its ops are not trusted until it catches up.
@immutable
class VaultState {
  const VaultState({
    required this.isSealed,
    required this.keyCount,
    required this.revokedCount,
    required this.revocationEpoch,
    required this.onDiskBytes,
  });

  final bool isSealed;
  final int keyCount;
  final int revokedCount;
  final int revocationEpoch;
  final int onDiskBytes;

  @override
  bool operator ==(Object other) =>
      other is VaultState &&
      other.isSealed == isSealed &&
      other.keyCount == keyCount &&
      other.revokedCount == revokedCount &&
      other.revocationEpoch == revocationEpoch &&
      other.onDiskBytes == onDiskBytes;

  @override
  int get hashCode => Object.hash(
    isSealed,
    keyCount,
    revokedCount,
    revocationEpoch,
    onDiskBytes,
  );
}
