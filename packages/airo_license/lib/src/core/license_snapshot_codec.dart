import 'dart:convert';

import 'capability.dart';
import 'license.dart';

/// UTC timestamp with second precision (`YYYY-MM-DDTHH:MM:SSZ`).
String licenseUtcSecondStamp(DateTime value) {
  final utc = value.toUtc();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${utc.year.toString().padLeft(4, '0')}-'
      '${two(utc.month)}-${two(utc.day)}T'
      '${two(utc.hour)}:${two(utc.minute)}:${two(utc.second)}Z';
}

DateTime parseLicenseUtcStamp(String raw) => DateTime.parse(raw).toUtc();

Map<String, Object?> _sortedJsonMap(Map<String, Object?> input) {
  final keys = input.keys.toList()..sort();
  return {for (final key in keys) key: _sortedJsonValue(input[key])};
}

Object? _sortedJsonValue(Object? value) {
  if (value is Map) {
    return _sortedJsonMap(
      value.map((key, dynamic v) => MapEntry(key.toString(), v as Object?)),
    );
  }
  if (value is List) {
    return [for (final item in value) _sortedJsonValue(item)];
  }
  return value;
}

/// Canonical payload the server signs. [LicenseSnapshot.signature] is omitted.
String licenseSnapshotCanonicalJson(LicenseSnapshot snapshot) {
  return jsonEncode(
    _sortedJsonMap({
      'capabilities': snapshot.capabilities.asMap,
      'entitlement': snapshot.entitlement.name,
      'expires_at': snapshot.expiresAt == null
          ? null
          : licenseUtcSecondStamp(snapshot.expiresAt!),
      'installation_id': snapshot.installationId,
      'issued_at': licenseUtcSecondStamp(snapshot.issuedAt),
      'license_id': snapshot.licenseId,
      'license_type': snapshot.licenseType.name,
      'max_devices': snapshot.devicePolicy.maxDevices,
      'policy_version': snapshot.policyVersion,
      'product_id': snapshot.productId,
      'status': snapshot.status.name,
    }),
  );
}

String _requireString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('$key is required');
  }
  return value;
}

T _enumByName<T extends Enum>(List<T> values, String name, T fallback) {
  for (final value in values) {
    if (value.name == name) return value;
  }
  return fallback;
}

/// Parses a hosted API snapshot. Does not verify [signature].
LicenseSnapshot licenseSnapshotFromJson(Map<String, Object?> json) {
  final capabilitiesRaw = json['capabilities'];
  final capabilities = capabilitiesRaw is Map
      ? LicenseCapabilities(
          capabilitiesRaw.map(
            (key, dynamic value) => MapEntry(key.toString(), value as Object?),
          ),
        )
      : LicenseCapabilities.empty;
  final expiresRaw = json['expires_at'];
  final issuedRaw = json['issued_at'];
  if (issuedRaw is! String) {
    throw const FormatException('issued_at is required');
  }
  return LicenseSnapshot(
    licenseId: _requireString(json, 'license_id'),
    productId: _requireString(json, 'product_id'),
    installationId: _requireString(json, 'installation_id'),
    issuedAt: parseLicenseUtcStamp(issuedRaw),
    licenseType: _enumByName(
      LicenseType.values,
      json['license_type'] as String? ?? 'free',
      LicenseType.free,
    ),
    entitlement: _enumByName(
      LicenseEntitlement.values,
      json['entitlement'] as String? ?? 'free',
      LicenseEntitlement.free,
    ),
    status: _enumByName(
      LicenseLifecycleStatus.values,
      json['status'] as String? ?? 'active',
      LicenseLifecycleStatus.active,
    ),
    devicePolicy: DevicePolicy(
      maxDevices: (json['max_devices'] as num?)?.toInt() ?? -1,
    ),
    capabilities: capabilities,
    policyVersion: (json['policy_version'] as num?)?.toInt() ?? 1,
    expiresAt: expiresRaw is String ? parseLicenseUtcStamp(expiresRaw) : null,
    signature: json['signature'] as String?,
    isLocalOnly: false,
  );
}

Map<String, Object?> licenseSnapshotToJson(LicenseSnapshot snapshot) {
  return {
    ...jsonDecode(licenseSnapshotCanonicalJson(snapshot))
        as Map<String, Object?>,
    if (snapshot.signature != null) 'signature': snapshot.signature,
  };
}
