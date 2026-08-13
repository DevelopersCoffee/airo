import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:equatable/equatable.dart';

/// Connectivity kind for a [AiroNetworkSnapshot], independent of platform
/// APIs — providers translate their own connectivity type into this set.
enum AiroNetworkLinkType { wifi, cellular, ethernet, offline, unknown }

/// Raw, unpersisted connectivity reading. [bssid] is only ever used to
/// derive a hashed [AiroNetworkKey] — never stored or transmitted as-is
/// (F7.6; `bssid` is also a hard-prohibited analytics field name, see
/// [AiroAnalyticsPrivacyFilter]).
class AiroNetworkSnapshot extends Equatable {
  const AiroNetworkSnapshot({
    required this.linkType,
    this.bssid,
    this.carrier,
    this.radioTechnology,
  });

  final AiroNetworkLinkType linkType;
  final String? bssid;
  final String? carrier;
  final String? radioTechnology;

  @override
  List<Object?> get props => [linkType, bssid, carrier, radioTechnology];
}

/// Stable identifier for the network a device is currently on, used to key
/// learned source-ranking data (F4.3.3) without ever persisting a raw
/// BSSID.
///
/// Formats: `wifi:<bssid-hash>`, `wifi:unknown` (no bssid available —
/// permission absent or not yet supplied), `cell:<carrier>:<radio-tech>`,
/// `ethernet`, `offline`.
class AiroNetworkKey {
  const AiroNetworkKey._();

  static String derive(
    AiroNetworkSnapshot snapshot, {
    required String installSalt,
  }) {
    switch (snapshot.linkType) {
      case AiroNetworkLinkType.wifi:
        final bssid = snapshot.bssid?.trim();
        if (bssid == null || bssid.isEmpty) return 'wifi:unknown';
        return 'wifi:${_hashBssid(bssid, installSalt)}';
      case AiroNetworkLinkType.cellular:
        final carrier = _segmentOrUnknown(snapshot.carrier);
        final tech = _segmentOrUnknown(snapshot.radioTechnology);
        return 'cell:$carrier:$tech';
      case AiroNetworkLinkType.ethernet:
        return 'ethernet';
      case AiroNetworkLinkType.offline:
        return 'offline';
      case AiroNetworkLinkType.unknown:
        return 'wifi:unknown';
    }
  }

  static String _segmentOrUnknown(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? 'unknown' : trimmed;
  }

  /// Salted so the same physical network hashes differently per install —
  /// hashes are keys for local ranking, not a cross-install identifier.
  static String _hashBssid(String bssid, String installSalt) {
    final digest = sha256.convert(utf8.encode('$installSalt:$bssid'));
    return digest.toString().substring(0, 16);
  }
}
