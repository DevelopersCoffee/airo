import 'package:equatable/equatable.dart';

const String kAiroExperimentationSchemaVersion = '1.0.0';

enum AiroExperimentProductProfile {
  fullTv('full_tv'),
  standardTv('standard_tv'),
  liteReceiver('lite_receiver'),
  embeddedReceiver('embedded_receiver'),
  mobileCompanion('mobile_companion'),
  desktopCompanion('desktop_companion');

  const AiroExperimentProductProfile(this.stableId);

  final String stableId;
}

enum AiroExperimentReleaseChannel {
  fullTvStable('full_tv_stable'),
  liteReceiverStable('lite_receiver_stable'),
  embeddedReceiverStable('embedded_receiver_stable'),
  legacyExperimental('legacy_experimental'),
  vendorSpecific('vendor_specific'),
  internalCertification('internal_certification');

  const AiroExperimentReleaseChannel(this.stableId);

  final String stableId;
}

enum AiroRemoteConfigOverrideKind {
  privacyConsent('privacy_consent'),
  securityControl('security_control'),
  entitlement('entitlement'),
  buildComposition('build_composition'),
  releaseChannel('release_channel'),
  minimumVersion('minimum_version');

  const AiroRemoteConfigOverrideKind(this.stableId);

  final String stableId;
}

enum AiroExperimentGuardrailCode {
  accepted('accepted'),
  disabled('disabled'),
  killed('killed'),
  noVariantAvailable('no_variant_available'),
  profileNotEligible('profile_not_eligible'),
  releaseChannelNotEligible('release_channel_not_eligible'),
  appVersionTooLow('app_version_too_low'),
  regionNotEligible('region_not_eligible'),
  rolloutNotEligible('rollout_not_eligible'),
  moduleAbsent('module_absent'),
  entitlementMissing('entitlement_missing'),
  privacyOverrideBlocked('privacy_override_blocked'),
  securityOverrideBlocked('security_override_blocked'),
  entitlementOverrideBlocked('entitlement_override_blocked'),
  buildCompositionOverrideBlocked('build_composition_override_blocked'),
  releaseChannelOverrideBlocked('release_channel_override_blocked'),
  minimumVersionOverrideBlocked('minimum_version_override_blocked');

  const AiroExperimentGuardrailCode(this.stableId);

  final String stableId;
}

class AiroExperimentSubject extends Equatable {
  AiroExperimentSubject({
    required this.assignmentKey,
    required this.productProfile,
    required this.releaseChannel,
    required this.appVersion,
    required this.regionBucket,
    Iterable<String> enabledModules = const {},
    Iterable<String> entitlements = const {},
    this.schemaVersion = kAiroExperimentationSchemaVersion,
  }) : enabledModules = Set.unmodifiable(enabledModules),
       entitlements = Set.unmodifiable(entitlements);

  final String schemaVersion;
  final String assignmentKey;
  final AiroExperimentProductProfile productProfile;
  final AiroExperimentReleaseChannel releaseChannel;
  final String appVersion;
  final String regionBucket;
  final Set<String> enabledModules;
  final Set<String> entitlements;

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'productProfile': productProfile.stableId,
      'releaseChannel': releaseChannel.stableId,
      'appVersion': appVersion,
      'regionBucket': regionBucket,
      'enabledModules': enabledModules.toList(growable: false)..sort(),
      'entitlements': entitlements.toList(growable: false)..sort(),
    };
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    assignmentKey,
    productProfile,
    releaseChannel,
    appVersion,
    regionBucket,
    enabledModules,
    entitlements,
  ];
}

class AiroExperimentVariant extends Equatable {
  const AiroExperimentVariant({
    required this.variantId,
    required this.weightBasisPoints,
  });

  final String variantId;
  final int weightBasisPoints;

  Map<String, Object?> toPublicMap() {
    return {'variantId': variantId, 'weightBasisPoints': weightBasisPoints};
  }

  @override
  List<Object?> get props => [variantId, weightBasisPoints];
}

class AiroExperimentDefinition extends Equatable {
  AiroExperimentDefinition({
    required this.experimentId,
    required Iterable<AiroExperimentVariant> variants,
    Iterable<AiroExperimentProductProfile> eligibleProfiles = const {},
    Iterable<AiroExperimentReleaseChannel> eligibleReleaseChannels = const {},
    Iterable<String> eligibleRegionBuckets = const {},
    Iterable<String> requiredModules = const {},
    Iterable<String> requiredEntitlements = const {},
    this.minAppVersion,
    this.rolloutBasisPoints = 10000,
    this.enabled = true,
    this.schemaVersion = kAiroExperimentationSchemaVersion,
  }) : variants = List.unmodifiable(variants),
       eligibleProfiles = Set.unmodifiable(eligibleProfiles),
       eligibleReleaseChannels = Set.unmodifiable(eligibleReleaseChannels),
       eligibleRegionBuckets = Set.unmodifiable(eligibleRegionBuckets),
       requiredModules = Set.unmodifiable(requiredModules),
       requiredEntitlements = Set.unmodifiable(requiredEntitlements);

  final String schemaVersion;
  final String experimentId;
  final List<AiroExperimentVariant> variants;
  final Set<AiroExperimentProductProfile> eligibleProfiles;
  final Set<AiroExperimentReleaseChannel> eligibleReleaseChannels;
  final Set<String> eligibleRegionBuckets;
  final Set<String> requiredModules;
  final Set<String> requiredEntitlements;
  final String? minAppVersion;
  final int rolloutBasisPoints;
  final bool enabled;

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'experimentId': experimentId,
      'variants': variants
          .map((variant) => variant.toPublicMap())
          .toList(growable: false),
      'eligibleProfiles':
          eligibleProfiles
              .map((profile) => profile.stableId)
              .toList(growable: false)
            ..sort(),
      'eligibleReleaseChannels':
          eligibleReleaseChannels
              .map((channel) => channel.stableId)
              .toList(growable: false)
            ..sort(),
      'eligibleRegionBuckets': eligibleRegionBuckets.toList(growable: false)
        ..sort(),
      'requiredModules': requiredModules.toList(growable: false)..sort(),
      'requiredEntitlements': requiredEntitlements.toList(growable: false)
        ..sort(),
      'minAppVersion': minAppVersion,
      'rolloutBasisPoints': rolloutBasisPoints,
      'enabled': enabled,
    };
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    experimentId,
    variants,
    eligibleProfiles,
    eligibleReleaseChannels,
    eligibleRegionBuckets,
    requiredModules,
    requiredEntitlements,
    minAppVersion,
    rolloutBasisPoints,
    enabled,
  ];
}

class AiroRemoteConfigFlag extends Equatable {
  AiroRemoteConfigFlag({
    required this.flagId,
    required this.valueCategory,
    Iterable<AiroExperimentProductProfile> eligibleProfiles = const {},
    Iterable<AiroExperimentReleaseChannel> eligibleReleaseChannels = const {},
    Iterable<String> eligibleRegionBuckets = const {},
    Iterable<String> requiredModules = const {},
    Iterable<String> requiredEntitlements = const {},
    Iterable<AiroRemoteConfigOverrideKind> requestedOverrides = const {},
    this.minAppVersion,
    this.rolloutBasisPoints = 10000,
    this.enabled = true,
    this.schemaVersion = kAiroExperimentationSchemaVersion,
  }) : eligibleProfiles = Set.unmodifiable(eligibleProfiles),
       eligibleReleaseChannels = Set.unmodifiable(eligibleReleaseChannels),
       eligibleRegionBuckets = Set.unmodifiable(eligibleRegionBuckets),
       requiredModules = Set.unmodifiable(requiredModules),
       requiredEntitlements = Set.unmodifiable(requiredEntitlements),
       requestedOverrides = Set.unmodifiable(requestedOverrides);

  final String schemaVersion;
  final String flagId;
  final String valueCategory;
  final Set<AiroExperimentProductProfile> eligibleProfiles;
  final Set<AiroExperimentReleaseChannel> eligibleReleaseChannels;
  final Set<String> eligibleRegionBuckets;
  final Set<String> requiredModules;
  final Set<String> requiredEntitlements;
  final Set<AiroRemoteConfigOverrideKind> requestedOverrides;
  final String? minAppVersion;
  final int rolloutBasisPoints;
  final bool enabled;

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'flagId': flagId,
      'valueCategory': valueCategory,
      'eligibleProfiles':
          eligibleProfiles
              .map((profile) => profile.stableId)
              .toList(growable: false)
            ..sort(),
      'eligibleReleaseChannels':
          eligibleReleaseChannels
              .map((channel) => channel.stableId)
              .toList(growable: false)
            ..sort(),
      'eligibleRegionBuckets': eligibleRegionBuckets.toList(growable: false)
        ..sort(),
      'requiredModules': requiredModules.toList(growable: false)..sort(),
      'requiredEntitlements': requiredEntitlements.toList(growable: false)
        ..sort(),
      'requestedOverrides':
          requestedOverrides
              .map((overrideKind) => overrideKind.stableId)
              .toList(growable: false)
            ..sort(),
      'minAppVersion': minAppVersion,
      'rolloutBasisPoints': rolloutBasisPoints,
      'enabled': enabled,
    };
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    flagId,
    valueCategory,
    eligibleProfiles,
    eligibleReleaseChannels,
    eligibleRegionBuckets,
    requiredModules,
    requiredEntitlements,
    requestedOverrides,
    minAppVersion,
    rolloutBasisPoints,
    enabled,
  ];
}

class AiroExperimentKillSwitchRegistry extends Equatable {
  AiroExperimentKillSwitchRegistry({
    Iterable<String> disabledIds = const {},
    this.schemaVersion = kAiroExperimentationSchemaVersion,
  }) : disabledIds = Set.unmodifiable(disabledIds);

  final String schemaVersion;
  final Set<String> disabledIds;

  bool isKilled(String id) => disabledIds.contains(id);

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'disabledIds': disabledIds.toList(growable: false)..sort(),
    };
  }

  @override
  List<Object?> get props => [schemaVersion, disabledIds];
}

class AiroExperimentDecision extends Equatable {
  AiroExperimentDecision({
    required this.targetId,
    required List<AiroExperimentGuardrailCode> codes,
    this.variantId,
    this.assignmentBucket,
  }) : codes = List.unmodifiable(codes);

  final String targetId;
  final String? variantId;
  final int? assignmentBucket;
  final List<AiroExperimentGuardrailCode> codes;

  bool get accepted =>
      codes.length == 1 && codes.single == AiroExperimentGuardrailCode.accepted;

  Map<String, Object?> toPublicMap() {
    return {
      'accepted': accepted,
      'targetId': targetId,
      'variantId': variantId,
      'assignmentBucket': assignmentBucket,
      'codes': codes.map((code) => code.stableId).toList(growable: false),
    };
  }

  @override
  List<Object?> get props => [targetId, variantId, assignmentBucket, codes];
}

class AiroExperimentEvaluator {
  AiroExperimentEvaluator({AiroExperimentKillSwitchRegistry? killSwitches})
    : killSwitches = killSwitches ?? AiroExperimentKillSwitchRegistry();

  final AiroExperimentKillSwitchRegistry killSwitches;

  AiroExperimentDecision evaluateExperiment({
    required AiroExperimentDefinition experiment,
    required AiroExperimentSubject subject,
  }) {
    final codes = _eligibilityCodes(
      targetId: experiment.experimentId,
      enabled: experiment.enabled,
      subject: subject,
      eligibleProfiles: experiment.eligibleProfiles,
      eligibleReleaseChannels: experiment.eligibleReleaseChannels,
      eligibleRegionBuckets: experiment.eligibleRegionBuckets,
      requiredModules: experiment.requiredModules,
      requiredEntitlements: experiment.requiredEntitlements,
      minAppVersion: experiment.minAppVersion,
      rolloutBasisPoints: experiment.rolloutBasisPoints,
      requestedOverrides: const {},
    );
    final bucket = _assignmentBucket(
      subject.assignmentKey,
      experiment.experimentId,
    );
    if (codes.isNotEmpty) {
      return AiroExperimentDecision(
        targetId: experiment.experimentId,
        assignmentBucket: bucket,
        codes: codes,
      );
    }
    final variant = _variantForBucket(experiment.variants, bucket);
    if (variant == null) {
      return AiroExperimentDecision(
        targetId: experiment.experimentId,
        assignmentBucket: bucket,
        codes: const [AiroExperimentGuardrailCode.noVariantAvailable],
      );
    }
    return AiroExperimentDecision(
      targetId: experiment.experimentId,
      variantId: variant.variantId,
      assignmentBucket: bucket,
      codes: const [AiroExperimentGuardrailCode.accepted],
    );
  }

  AiroExperimentDecision evaluateRemoteConfig({
    required AiroRemoteConfigFlag flag,
    required AiroExperimentSubject subject,
  }) {
    final codes = _eligibilityCodes(
      targetId: flag.flagId,
      enabled: flag.enabled,
      subject: subject,
      eligibleProfiles: flag.eligibleProfiles,
      eligibleReleaseChannels: flag.eligibleReleaseChannels,
      eligibleRegionBuckets: flag.eligibleRegionBuckets,
      requiredModules: flag.requiredModules,
      requiredEntitlements: flag.requiredEntitlements,
      minAppVersion: flag.minAppVersion,
      rolloutBasisPoints: flag.rolloutBasisPoints,
      requestedOverrides: flag.requestedOverrides,
    );
    final bucket = _assignmentBucket(subject.assignmentKey, flag.flagId);
    return AiroExperimentDecision(
      targetId: flag.flagId,
      assignmentBucket: bucket,
      codes: codes.isEmpty
          ? const [AiroExperimentGuardrailCode.accepted]
          : codes,
    );
  }

  List<AiroExperimentGuardrailCode> _eligibilityCodes({
    required String targetId,
    required bool enabled,
    required AiroExperimentSubject subject,
    required Set<AiroExperimentProductProfile> eligibleProfiles,
    required Set<AiroExperimentReleaseChannel> eligibleReleaseChannels,
    required Set<String> eligibleRegionBuckets,
    required Set<String> requiredModules,
    required Set<String> requiredEntitlements,
    required String? minAppVersion,
    required int rolloutBasisPoints,
    required Set<AiroRemoteConfigOverrideKind> requestedOverrides,
  }) {
    final codes = <AiroExperimentGuardrailCode>[];
    if (!enabled) {
      codes.add(AiroExperimentGuardrailCode.disabled);
    }
    if (killSwitches.isKilled(targetId)) {
      codes.add(AiroExperimentGuardrailCode.killed);
    }
    if (eligibleProfiles.isNotEmpty &&
        !eligibleProfiles.contains(subject.productProfile)) {
      codes.add(AiroExperimentGuardrailCode.profileNotEligible);
    }
    if (eligibleReleaseChannels.isNotEmpty &&
        !eligibleReleaseChannels.contains(subject.releaseChannel)) {
      codes.add(AiroExperimentGuardrailCode.releaseChannelNotEligible);
    }
    if (minAppVersion != null &&
        _compareVersions(subject.appVersion, minAppVersion) < 0) {
      codes.add(AiroExperimentGuardrailCode.appVersionTooLow);
    }
    if (eligibleRegionBuckets.isNotEmpty &&
        !eligibleRegionBuckets.contains(subject.regionBucket)) {
      codes.add(AiroExperimentGuardrailCode.regionNotEligible);
    }
    if (_assignmentBucket(subject.assignmentKey, targetId) >=
        rolloutBasisPoints.clamp(0, 10000)) {
      codes.add(AiroExperimentGuardrailCode.rolloutNotEligible);
    }
    if (!subject.enabledModules.containsAll(requiredModules)) {
      codes.add(AiroExperimentGuardrailCode.moduleAbsent);
    }
    if (!subject.entitlements.containsAll(requiredEntitlements)) {
      codes.add(AiroExperimentGuardrailCode.entitlementMissing);
    }
    codes.addAll(_overrideCodes(requestedOverrides));
    return codes.toSet().toList(growable: false);
  }
}

AiroExperimentVariant? _variantForBucket(
  List<AiroExperimentVariant> variants,
  int bucket,
) {
  var cumulative = 0;
  for (final variant in variants) {
    if (variant.weightBasisPoints <= 0) continue;
    cumulative += variant.weightBasisPoints;
    if (bucket < cumulative.clamp(0, 10000)) {
      return variant;
    }
  }
  return null;
}

List<AiroExperimentGuardrailCode> _overrideCodes(
  Set<AiroRemoteConfigOverrideKind> overrides,
) {
  final codes = <AiroExperimentGuardrailCode>[];
  if (overrides.contains(AiroRemoteConfigOverrideKind.privacyConsent)) {
    codes.add(AiroExperimentGuardrailCode.privacyOverrideBlocked);
  }
  if (overrides.contains(AiroRemoteConfigOverrideKind.securityControl)) {
    codes.add(AiroExperimentGuardrailCode.securityOverrideBlocked);
  }
  if (overrides.contains(AiroRemoteConfigOverrideKind.entitlement)) {
    codes.add(AiroExperimentGuardrailCode.entitlementOverrideBlocked);
  }
  if (overrides.contains(AiroRemoteConfigOverrideKind.buildComposition)) {
    codes.add(AiroExperimentGuardrailCode.buildCompositionOverrideBlocked);
  }
  if (overrides.contains(AiroRemoteConfigOverrideKind.releaseChannel)) {
    codes.add(AiroExperimentGuardrailCode.releaseChannelOverrideBlocked);
  }
  if (overrides.contains(AiroRemoteConfigOverrideKind.minimumVersion)) {
    codes.add(AiroExperimentGuardrailCode.minimumVersionOverrideBlocked);
  }
  return codes;
}

int _assignmentBucket(String assignmentKey, String targetId) {
  return _fnv1a32('$assignmentKey:$targetId') % 10000;
}

int _fnv1a32(String value) {
  var hash = 0x811c9dc5;
  for (final codeUnit in value.codeUnits) {
    hash ^= codeUnit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash;
}

int _compareVersions(String left, String right) {
  final leftParts = _versionParts(left);
  final rightParts = _versionParts(right);
  final maxLength = leftParts.length > rightParts.length
      ? leftParts.length
      : rightParts.length;
  for (var index = 0; index < maxLength; index += 1) {
    final leftValue = index < leftParts.length ? leftParts[index] : 0;
    final rightValue = index < rightParts.length ? rightParts[index] : 0;
    if (leftValue != rightValue) return leftValue.compareTo(rightValue);
  }
  return 0;
}

List<int> _versionParts(String value) {
  return value
      .split('.')
      .map((part) => int.tryParse(part) ?? 0)
      .toList(growable: false);
}
