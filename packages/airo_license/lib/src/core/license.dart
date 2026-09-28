import 'capability.dart';

enum LicenseType { free, lifetime, subscription }

enum LicenseEntitlement { free, pro }

enum LicenseLifecycleStatus { active, revoked, suspended, expired }

enum InstallationLifecycleStatus { active, inactive, deactivated, revoked }

/// `-1` means unlimited installations. Counting is a server concern; this
/// object only carries the policy the client last observed.
final class DevicePolicy {
  const DevicePolicy({this.maxDevices = -1});

  final int maxDevices;

  bool get isUnlimited => maxDevices < 0;
}

final class Installation {
  const Installation({
    required this.installationId,
    this.publicKey,
    this.platform,
    this.deviceType,
    this.appVersion,
    this.status = InstallationLifecycleStatus.active,
  });

  final String installationId;
  final String? publicKey;
  final String? platform;
  final String? deviceType;
  final String? appVersion;
  final InstallationLifecycleStatus status;
}

/// Last-known license state. Local-first snapshots have [isLocalOnly] true
/// and no signature. A hosted overlay client may attach a signature later.
final class LicenseSnapshot {
  const LicenseSnapshot({
    required this.licenseId,
    required this.productId,
    required this.installationId,
    required this.issuedAt,
    this.licenseType = LicenseType.free,
    this.entitlement = LicenseEntitlement.free,
    this.status = LicenseLifecycleStatus.active,
    this.devicePolicy = const DevicePolicy(),
    this.capabilities = LicenseCapabilities.empty,
    this.policyVersion = 1,
    this.expiresAt,
    this.signature,
    this.isLocalOnly = true,
  });

  final String licenseId;
  final String productId;
  final String installationId;
  final LicenseType licenseType;
  final LicenseEntitlement entitlement;
  final LicenseLifecycleStatus status;
  final DevicePolicy devicePolicy;
  final LicenseCapabilities capabilities;
  final int policyVersion;
  final DateTime issuedAt;
  final DateTime? expiresAt;
  final String? signature;
  final bool isLocalOnly;

  bool hasCapability(String capabilityId) {
    if (status != LicenseLifecycleStatus.active) return false;
    if (entitlement == LicenseEntitlement.free) return false;
    return capabilities.has(capabilityId);
  }

  LicenseSnapshot copyWith({
    LicenseType? licenseType,
    LicenseEntitlement? entitlement,
    LicenseLifecycleStatus? status,
    DevicePolicy? devicePolicy,
    LicenseCapabilities? capabilities,
    DateTime? issuedAt,
    bool? isLocalOnly,
  }) {
    return LicenseSnapshot(
      licenseId: licenseId,
      productId: productId,
      installationId: installationId,
      issuedAt: issuedAt ?? this.issuedAt,
      licenseType: licenseType ?? this.licenseType,
      entitlement: entitlement ?? this.entitlement,
      status: status ?? this.status,
      devicePolicy: devicePolicy ?? this.devicePolicy,
      capabilities: capabilities ?? this.capabilities,
      policyVersion: policyVersion,
      expiresAt: expiresAt,
      signature: signature,
      isLocalOnly: isLocalOnly ?? this.isLocalOnly,
    );
  }
}
