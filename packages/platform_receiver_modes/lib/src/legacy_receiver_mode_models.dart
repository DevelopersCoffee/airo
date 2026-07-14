import 'package:equatable/equatable.dart';
import 'package:platform_device_profile/platform_device_profile.dart';
import 'package:product_capabilities/product_capabilities.dart';

const String kLegacyReceiverModeSchemaVersion = '1.0.0';

enum LegacyReceiverModeId {
  off('off'),
  liteReceiver('lite_receiver'),
  restrictedLiteReceiver('restricted_lite_receiver'),
  blocked('blocked');

  const LegacyReceiverModeId(this.stableId);

  final String stableId;
}

enum LegacyReceiverModeTrigger {
  runtimeProfile('runtime_profile'),
  resourcePressure('resource_pressure'),
  restrictedTrust('restricted_trust'),
  unsupportedProfile('unsupported_profile'),
  operatorOverride('operator_override');

  const LegacyReceiverModeTrigger(this.stableId);

  final String stableId;
}

enum LegacyReceiverHomeSection {
  continueWatching('continue_watching'),
  liveNow('live_now'),
  favorites('favorites'),
  recent('recent'),
  pairedDeviceStatus('paired_device_status'),
  phoneSearch('phone_search'),
  currentProgram('current_program'),
  settings('settings'),
  diagnostics('diagnostics');

  const LegacyReceiverHomeSection(this.stableId);

  final String stableId;
}

enum LegacyReceiverArtworkPolicy {
  textOnly('text_only'),
  iconsOnly('icons_only'),
  compactThumbnails('compact_thumbnails'),
  standardThumbnails('standard_thumbnails');

  const LegacyReceiverArtworkPolicy(this.stableId);

  final String stableId;
}

enum LegacyReceiverMotionPolicy {
  none('none'),
  focusOnly('focus_only'),
  reduced('reduced'),
  standard('standard');

  const LegacyReceiverMotionPolicy(this.stableId);

  final String stableId;
}

enum LegacyReceiverDelegationCapability {
  companionSearch('companion_search'),
  companionEpg('companion_epg'),
  companionAi('companion_ai'),
  companionPlaybackResolve('companion_playback_resolve'),
  companionRemote('companion_remote'),
  streamRecovery('stream_recovery');

  const LegacyReceiverDelegationCapability(this.stableId);

  final String stableId;
}

class LegacyReceiverDataBudget extends Equatable {
  const LegacyReceiverDataBudget({
    required this.epgPastHours,
    required this.epgFutureHours,
    required this.catalogPageSize,
    required this.maxRecentItems,
    required this.maxFavoriteItems,
    required this.allowFullLocalIndex,
    required this.allowBackgroundEnrichment,
  });

  final int epgPastHours;
  final int epgFutureHours;
  final int catalogPageSize;
  final int maxRecentItems;
  final int maxFavoriteItems;
  final bool allowFullLocalIndex;
  final bool allowBackgroundEnrichment;

  Map<String, Object?> toPublicMap() {
    return {
      'epgPastHours': epgPastHours,
      'epgFutureHours': epgFutureHours,
      'catalogPageSize': catalogPageSize,
      'maxRecentItems': maxRecentItems,
      'maxFavoriteItems': maxFavoriteItems,
      'allowFullLocalIndex': allowFullLocalIndex,
      'allowBackgroundEnrichment': allowBackgroundEnrichment,
    };
  }

  @override
  List<Object?> get props => [
    epgPastHours,
    epgFutureHours,
    catalogPageSize,
    maxRecentItems,
    maxFavoriteItems,
    allowFullLocalIndex,
    allowBackgroundEnrichment,
  ];
}

class LegacyReceiverVisualBudget extends Equatable {
  const LegacyReceiverVisualBudget({
    required this.artworkPolicy,
    required this.motionPolicy,
    required this.maxArtworkCacheMb,
    required this.allowAnimatedPreviews,
    required this.allowBlurEffects,
    required this.allowAutoplayPreviews,
  });

  final LegacyReceiverArtworkPolicy artworkPolicy;
  final LegacyReceiverMotionPolicy motionPolicy;
  final int maxArtworkCacheMb;
  final bool allowAnimatedPreviews;
  final bool allowBlurEffects;
  final bool allowAutoplayPreviews;

  Map<String, Object?> toPublicMap() {
    return {
      'artworkPolicy': artworkPolicy.stableId,
      'motionPolicy': motionPolicy.stableId,
      'maxArtworkCacheMb': maxArtworkCacheMb,
      'allowAnimatedPreviews': allowAnimatedPreviews,
      'allowBlurEffects': allowBlurEffects,
      'allowAutoplayPreviews': allowAutoplayPreviews,
    };
  }

  @override
  List<Object?> get props => [
    artworkPolicy,
    motionPolicy,
    maxArtworkCacheMb,
    allowAnimatedPreviews,
    allowBlurEffects,
    allowAutoplayPreviews,
  ];
}

class LegacyReceiverDelegationPolicy extends Equatable {
  LegacyReceiverDelegationPolicy({
    required Set<LegacyReceiverDelegationCapability> preferred,
    required Set<LegacyReceiverDelegationCapability> required,
    required this.allowStandalonePlayback,
    required this.allowCompanionDiscovery,
  }) : preferred = Set.unmodifiable(preferred),
       required = Set.unmodifiable(required);

  final Set<LegacyReceiverDelegationCapability> preferred;
  final Set<LegacyReceiverDelegationCapability> required;
  final bool allowStandalonePlayback;
  final bool allowCompanionDiscovery;

  Map<String, Object?> toPublicMap() {
    return {
      'preferred': preferred
          .map((capability) => capability.stableId)
          .toList(growable: false),
      'required': required
          .map((capability) => capability.stableId)
          .toList(growable: false),
      'allowStandalonePlayback': allowStandalonePlayback,
      'allowCompanionDiscovery': allowCompanionDiscovery,
    };
  }

  @override
  List<Object?> get props => [
    preferred,
    required,
    allowStandalonePlayback,
    allowCompanionDiscovery,
  ];
}

class LegacyReceiverModeContract extends Equatable {
  LegacyReceiverModeContract({
    required this.contractId,
    required this.modeId,
    required this.sourceProfileId,
    required this.enabled,
    required this.activationBlocked,
    required this.recommendedProductProfile,
    required Iterable<LegacyReceiverModeTrigger> triggers,
    required Iterable<ProductNavigationEntry> navigation,
    required Iterable<LegacyReceiverHomeSection> homeSections,
    required Iterable<ProductModule> includedModules,
    required Iterable<ProductModule> disabledModules,
    required this.dataBudget,
    required this.visualBudget,
    required this.delegationPolicy,
    required this.resourceBudget,
    required Iterable<AiroRuntimeConstraintCode> runtimeConstraints,
    required this.capturedAt,
    this.schemaVersion = kLegacyReceiverModeSchemaVersion,
  }) : triggers = List.unmodifiable(triggers),
       navigation = List.unmodifiable(navigation),
       homeSections = List.unmodifiable(homeSections),
       includedModules = Set.unmodifiable(includedModules),
       disabledModules = Set.unmodifiable(disabledModules),
       runtimeConstraints = List.unmodifiable(runtimeConstraints);

  final String schemaVersion;
  final String contractId;
  final LegacyReceiverModeId modeId;
  final String sourceProfileId;
  final bool enabled;
  final bool activationBlocked;
  final ProductProfileId recommendedProductProfile;
  final List<LegacyReceiverModeTrigger> triggers;
  final List<ProductNavigationEntry> navigation;
  final List<LegacyReceiverHomeSection> homeSections;
  final Set<ProductModule> includedModules;
  final Set<ProductModule> disabledModules;
  final LegacyReceiverDataBudget dataBudget;
  final LegacyReceiverVisualBudget visualBudget;
  final LegacyReceiverDelegationPolicy delegationPolicy;
  final ProductResourceBudget resourceBudget;
  final List<AiroRuntimeConstraintCode> runtimeConstraints;
  final DateTime capturedAt;

  bool get usesLegacyReceiverMode =>
      enabled && modeId != LegacyReceiverModeId.off;

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'contractId': contractId,
      'modeId': modeId.stableId,
      'sourceProfileId': sourceProfileId,
      'enabled': enabled,
      'activationBlocked': activationBlocked,
      'recommendedProductProfile': recommendedProductProfile.stableId,
      'triggers': triggers
          .map((trigger) => trigger.stableId)
          .toList(growable: false),
      'navigation': navigation
          .map((entry) => entry.stableId)
          .toList(growable: false),
      'homeSections': homeSections
          .map((section) => section.stableId)
          .toList(growable: false),
      'includedModules': includedModules
          .map((module) => module.stableId)
          .toList(growable: false),
      'disabledModules': disabledModules
          .map((module) => module.stableId)
          .toList(growable: false),
      'dataBudget': dataBudget.toPublicMap(),
      'visualBudget': visualBudget.toPublicMap(),
      'delegationPolicy': delegationPolicy.toPublicMap(),
      'resourceBudget': {
        'maxMemoryMb': resourceBudget.maxMemoryMb,
        'maxStorageMb': resourceBudget.maxStorageMb,
        'maxArtworkCacheMb': resourceBudget.maxArtworkCacheMb,
        'maxBackgroundJobs': resourceBudget.maxBackgroundJobs,
      },
      'runtimeConstraints': runtimeConstraints
          .map((constraint) => constraint.stableId)
          .toList(growable: false),
      'capturedAt': capturedAt.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    contractId,
    modeId,
    sourceProfileId,
    enabled,
    activationBlocked,
    recommendedProductProfile,
    triggers,
    navigation,
    homeSections,
    includedModules,
    disabledModules,
    dataBudget,
    visualBudget,
    delegationPolicy,
    resourceBudget,
    runtimeConstraints,
    capturedAt,
  ];
}

class LegacyReceiverModePolicy extends Equatable {
  const LegacyReceiverModePolicy({
    this.fullTvManifestProvider = AiroTvProductProfiles.fullTv,
    this.liteReceiverManifestProvider = AiroTvProductProfiles.liteReceiver,
  });

  final ProductProfileManifest Function() fullTvManifestProvider;
  final ProductProfileManifest Function() liteReceiverManifestProvider;

  LegacyReceiverModeContract evaluate({
    required AiroRuntimeDeviceProfile runtimeProfile,
    required DateTime now,
    bool operatorForcesLegacy = false,
  }) {
    final triggers = _triggersFor(runtimeProfile, operatorForcesLegacy);

    if (runtimeProfile.supportTier == AiroRuntimeSupportTier.unsupported) {
      return _blockedContract(
        runtimeProfile: runtimeProfile,
        triggers: triggers,
        now: now,
      );
    }

    if (!runtimeProfile.legacyReceiverModeRecommended &&
        !operatorForcesLegacy) {
      return _offContract(
        runtimeProfile: runtimeProfile,
        triggers: triggers,
        now: now,
      );
    }

    final restricted = runtimeProfile.restrictedReceiverTrustRequired;
    return _liteContract(
      runtimeProfile: runtimeProfile,
      modeId: restricted
          ? LegacyReceiverModeId.restrictedLiteReceiver
          : LegacyReceiverModeId.liteReceiver,
      triggers: triggers,
      restricted: restricted,
      now: now,
    );
  }

  LegacyReceiverModeContract _offContract({
    required AiroRuntimeDeviceProfile runtimeProfile,
    required List<LegacyReceiverModeTrigger> triggers,
    required DateTime now,
  }) {
    final manifest = fullTvManifestProvider();
    return LegacyReceiverModeContract(
      contractId: 'legacy-mode-${runtimeProfile.profileId}',
      modeId: LegacyReceiverModeId.off,
      sourceProfileId: runtimeProfile.profileId,
      enabled: false,
      activationBlocked: false,
      recommendedProductProfile: manifest.profileId,
      triggers: triggers,
      navigation: manifest.navigation,
      homeSections: const [
        LegacyReceiverHomeSection.continueWatching,
        LegacyReceiverHomeSection.liveNow,
        LegacyReceiverHomeSection.favorites,
        LegacyReceiverHomeSection.recent,
        LegacyReceiverHomeSection.settings,
      ],
      includedModules: manifest.includedModules,
      disabledModules: manifest.excludedModules,
      dataBudget: const LegacyReceiverDataBudget(
        epgPastHours: 24,
        epgFutureHours: 48,
        catalogPageSize: 100,
        maxRecentItems: 100,
        maxFavoriteItems: 500,
        allowFullLocalIndex: true,
        allowBackgroundEnrichment: true,
      ),
      visualBudget: LegacyReceiverVisualBudget(
        artworkPolicy: LegacyReceiverArtworkPolicy.standardThumbnails,
        motionPolicy: LegacyReceiverMotionPolicy.standard,
        maxArtworkCacheMb: manifest.resourceBudget.maxArtworkCacheMb,
        allowAnimatedPreviews: true,
        allowBlurEffects: true,
        allowAutoplayPreviews: true,
      ),
      delegationPolicy: LegacyReceiverDelegationPolicy(
        preferred: const {LegacyReceiverDelegationCapability.companionRemote},
        required: const {},
        allowStandalonePlayback: true,
        allowCompanionDiscovery: true,
      ),
      resourceBudget: manifest.resourceBudget,
      runtimeConstraints: runtimeProfile.constraints,
      capturedAt: now,
    );
  }

  LegacyReceiverModeContract _liteContract({
    required AiroRuntimeDeviceProfile runtimeProfile,
    required LegacyReceiverModeId modeId,
    required List<LegacyReceiverModeTrigger> triggers,
    required bool restricted,
    required DateTime now,
  }) {
    final manifest = liteReceiverManifestProvider();
    return LegacyReceiverModeContract(
      contractId: 'legacy-mode-${runtimeProfile.profileId}',
      modeId: modeId,
      sourceProfileId: runtimeProfile.profileId,
      enabled: true,
      activationBlocked: false,
      recommendedProductProfile: manifest.profileId,
      triggers: triggers,
      navigation: manifest.navigation,
      homeSections: const [
        LegacyReceiverHomeSection.continueWatching,
        LegacyReceiverHomeSection.liveNow,
        LegacyReceiverHomeSection.favorites,
        LegacyReceiverHomeSection.recent,
        LegacyReceiverHomeSection.pairedDeviceStatus,
        LegacyReceiverHomeSection.phoneSearch,
        LegacyReceiverHomeSection.currentProgram,
        LegacyReceiverHomeSection.settings,
        LegacyReceiverHomeSection.diagnostics,
      ],
      includedModules: manifest.includedModules,
      disabledModules: {
        ...manifest.excludedModules,
        ProductModule.fullEpg,
        ProductModule.localAi,
        ProductModule.recording,
        ProductModule.downloads,
        ProductModule.multiview,
      },
      dataBudget: LegacyReceiverDataBudget(
        epgPastHours: 0,
        epgFutureHours: restricted ? 2 : 6,
        catalogPageSize: restricted ? 16 : 25,
        maxRecentItems: restricted ? 12 : 25,
        maxFavoriteItems: restricted ? 25 : 50,
        allowFullLocalIndex: false,
        allowBackgroundEnrichment: false,
      ),
      visualBudget: LegacyReceiverVisualBudget(
        artworkPolicy: restricted
            ? LegacyReceiverArtworkPolicy.iconsOnly
            : LegacyReceiverArtworkPolicy.compactThumbnails,
        motionPolicy: LegacyReceiverMotionPolicy.focusOnly,
        maxArtworkCacheMb: manifest.resourceBudget.maxArtworkCacheMb,
        allowAnimatedPreviews: false,
        allowBlurEffects: false,
        allowAutoplayPreviews: false,
      ),
      delegationPolicy: LegacyReceiverDelegationPolicy(
        preferred: const {
          LegacyReceiverDelegationCapability.companionSearch,
          LegacyReceiverDelegationCapability.companionEpg,
          LegacyReceiverDelegationCapability.companionAi,
          LegacyReceiverDelegationCapability.companionPlaybackResolve,
          LegacyReceiverDelegationCapability.companionRemote,
          LegacyReceiverDelegationCapability.streamRecovery,
        },
        required: restricted
            ? const {
                LegacyReceiverDelegationCapability.companionPlaybackResolve,
              }
            : const {},
        allowStandalonePlayback: true,
        allowCompanionDiscovery: !restricted,
      ),
      resourceBudget: manifest.resourceBudget,
      runtimeConstraints: runtimeProfile.constraints,
      capturedAt: now,
    );
  }

  LegacyReceiverModeContract _blockedContract({
    required AiroRuntimeDeviceProfile runtimeProfile,
    required List<LegacyReceiverModeTrigger> triggers,
    required DateTime now,
  }) {
    const resourceBudget = ProductResourceBudget(
      maxMemoryMb: 128,
      maxStorageMb: 32,
      maxArtworkCacheMb: 0,
      maxBackgroundJobs: 0,
    );
    return LegacyReceiverModeContract(
      contractId: 'legacy-mode-${runtimeProfile.profileId}',
      modeId: LegacyReceiverModeId.blocked,
      sourceProfileId: runtimeProfile.profileId,
      enabled: false,
      activationBlocked: true,
      recommendedProductProfile: ProductProfileId.embeddedReceiver,
      triggers: {...triggers, LegacyReceiverModeTrigger.unsupportedProfile},
      navigation: const [
        ProductNavigationEntry.settings,
        ProductNavigationEntry.diagnostics,
      ],
      homeSections: const [
        LegacyReceiverHomeSection.settings,
        LegacyReceiverHomeSection.diagnostics,
      ],
      includedModules: const {ProductModule.diagnostics},
      disabledModules: ProductModule.values.where(
        (module) => module != ProductModule.diagnostics,
      ),
      dataBudget: const LegacyReceiverDataBudget(
        epgPastHours: 0,
        epgFutureHours: 0,
        catalogPageSize: 0,
        maxRecentItems: 0,
        maxFavoriteItems: 0,
        allowFullLocalIndex: false,
        allowBackgroundEnrichment: false,
      ),
      visualBudget: const LegacyReceiverVisualBudget(
        artworkPolicy: LegacyReceiverArtworkPolicy.textOnly,
        motionPolicy: LegacyReceiverMotionPolicy.none,
        maxArtworkCacheMb: 0,
        allowAnimatedPreviews: false,
        allowBlurEffects: false,
        allowAutoplayPreviews: false,
      ),
      delegationPolicy: LegacyReceiverDelegationPolicy(
        preferred: const {},
        required: const {},
        allowStandalonePlayback: false,
        allowCompanionDiscovery: false,
      ),
      resourceBudget: resourceBudget,
      runtimeConstraints: runtimeProfile.constraints,
      capturedAt: now,
    );
  }

  List<LegacyReceiverModeTrigger> _triggersFor(
    AiroRuntimeDeviceProfile runtimeProfile,
    bool operatorForcesLegacy,
  ) {
    final triggers = <LegacyReceiverModeTrigger>{};
    if (runtimeProfile.legacyReceiverModeRecommended) {
      triggers.add(LegacyReceiverModeTrigger.runtimeProfile);
    }
    if (runtimeProfile.constraints.any(_isPressureConstraint)) {
      triggers.add(LegacyReceiverModeTrigger.resourcePressure);
    }
    if (runtimeProfile.restrictedReceiverTrustRequired) {
      triggers.add(LegacyReceiverModeTrigger.restrictedTrust);
    }
    if (runtimeProfile.supportTier == AiroRuntimeSupportTier.unsupported) {
      triggers.add(LegacyReceiverModeTrigger.unsupportedProfile);
    }
    if (operatorForcesLegacy) {
      triggers.add(LegacyReceiverModeTrigger.operatorOverride);
    }
    return List.unmodifiable(triggers);
  }

  bool _isPressureConstraint(AiroRuntimeConstraintCode constraint) {
    return constraint == AiroRuntimeConstraintCode.memoryLow ||
        constraint == AiroRuntimeConstraintCode.storageLow ||
        constraint == AiroRuntimeConstraintCode.thermalPressure ||
        constraint == AiroRuntimeConstraintCode.networkConstrained ||
        constraint == AiroRuntimeConstraintCode.decoderFailurePressure;
  }

  @override
  List<Object?> get props => [
    fullTvManifestProvider,
    liteReceiverManifestProvider,
  ];
}
