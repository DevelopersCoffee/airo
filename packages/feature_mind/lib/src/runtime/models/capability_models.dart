import 'package:flutter/foundation.dart';

/// What a capability is allowed to claim, and therefore what warning its
/// surfaces must carry.
///
/// The Agent Chat safety banner is driven by this, not hardcoded per screen —
/// a health capability gets the wellness-only notice wherever it appears.
enum CapabilitySafetyClass { general, health, financial, legal }

/// An installed capability pack.
@immutable
class InstalledCapability {
  const InstalledCapability({
    required this.id,
    required this.name,
    required this.version,
    required this.isFirstParty,
    required this.isActive,
    required this.itemCount,
    required this.safetyClass,
    this.requiresConsentFor = const [],
  });

  final String id;
  final String name;
  final String version;
  final bool isFirstParty;
  final bool isActive;
  final int itemCount;
  final CapabilitySafetyClass safetyClass;

  /// Resources this pack cannot touch without an explicit consent gate — `mic`
  /// for Audio Scribe. Printed on the row, never buried in a sheet.
  final List<String> requiresConsentFor;

  @override
  bool operator ==(Object other) =>
      other is InstalledCapability &&
      other.id == id &&
      other.name == name &&
      other.version == version &&
      other.isFirstParty == isFirstParty &&
      other.isActive == isActive &&
      other.itemCount == itemCount &&
      other.safetyClass == safetyClass &&
      listEquals(other.requiresConsentFor, requiresConsentFor);

  @override
  int get hashCode => Object.hash(
    id,
    name,
    version,
    isFirstParty,
    isActive,
    itemCount,
    safetyClass,
    Object.hashAll(requiresConsentFor),
  );
}
