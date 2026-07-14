import 'package:equatable/equatable.dart';

const String kProductCapabilitiesSchemaVersion = '1.0.0';

enum ProductProfileId {
  fullTv('full_tv'),
  standardTv('standard_tv'),
  liteReceiver('lite_receiver'),
  embeddedReceiver('embedded_receiver'),
  experimentalLegacy('experimental_legacy');

  const ProductProfileId(this.stableId);

  final String stableId;
}

enum ProductSupportLevel {
  certified('certified'),
  compatible('compatible'),
  experimental('experimental'),
  unsupported('unsupported');

  const ProductSupportLevel(this.stableId);

  final String stableId;
}

enum ProductReleaseChannel {
  fullTvStable('full_tv_stable'),
  liteReceiverStable('lite_receiver_stable'),
  receiverStable('receiver_stable'),
  legacyExperimental('legacy_experimental'),
  vendorSpecific('vendor_specific'),
  internalCertification('internal_certification');

  const ProductReleaseChannel(this.stableId);

  final String stableId;
}

enum ProductModule {
  playback('playback'),
  playlistImport('playlist_import'),
  favorites('favorites'),
  recent('recent'),
  basicSearch('basic_search'),
  compactEpg('compact_epg'),
  fullEpg('full_epg'),
  pairing('pairing'),
  remoteControl('remote_control'),
  diagnostics('diagnostics'),
  analytics('analytics'),
  localAi('local_ai'),
  recording('recording'),
  downloads('downloads'),
  multiview('multiview');

  const ProductModule(this.stableId);

  final String stableId;
}

enum ProductProfileGuarantee {
  byocOnly('byoc_only'),
  directPlayback('direct_playback'),
  dpadNavigation('dpad_navigation'),
  companionRemote('companion_remote'),
  compactData('compact_data'),
  noBundledContent('no_bundled_content'),
  permissionMinimized('permission_minimized'),
  restrictedTrustCompatible('restricted_trust_compatible'),
  profileScopedNavigation('profile_scoped_navigation');

  const ProductProfileGuarantee(this.stableId);

  final String stableId;
}

enum ProductNavigationEntry {
  home('home'),
  live('live'),
  guide('guide'),
  favorites('favorites'),
  recent('recent'),
  search('search'),
  settings('settings'),
  diagnostics('diagnostics'),
  profiles('profiles');

  const ProductNavigationEntry(this.stableId);

  final String stableId;
}

enum ProductNavigationRenderTier {
  rich('rich'),
  standard('standard'),
  lightweight('lightweight');

  const ProductNavigationRenderTier(this.stableId);

  final String stableId;
}

enum ProductManifestValidationCode {
  accepted('accepted'),
  moduleOverlap('module_overlap'),
  navigationUnsupported('navigation_unsupported'),
  capabilityUnsupported('capability_unsupported'),
  permissionUnsupported('permission_unsupported'),
  budgetInvalid('budget_invalid'),
  releaseChannelMismatch('release_channel_mismatch'),
  supportLevelMismatch('support_level_mismatch');

  const ProductManifestValidationCode(this.stableId);

  final String stableId;
}

enum ProductNavigationValidationCode {
  accepted('accepted'),
  profileMismatch('profile_mismatch'),
  routeIdMissing('route_id_missing'),
  displayKeyMissing('display_key_missing'),
  duplicateRouteId('duplicate_route_id'),
  entryUnsupported('entry_unsupported'),
  moduleUnavailable('module_unavailable'),
  capabilityUnsupported('capability_unsupported'),
  compositionModuleNotCompiled('composition_module_not_compiled'),
  renderTierUnsupported('render_tier_unsupported');

  const ProductNavigationValidationCode(this.stableId);

  final String stableId;
}

enum ProductModuleLifecycleValidationCode {
  accepted('accepted'),
  unsupportedProfile('unsupported_profile'),
  moduleUnavailable('module_unavailable'),
  dependencyMissing('dependency_missing'),
  capabilityUnsupported('capability_unsupported'),
  permissionUnsupported('permission_unsupported'),
  budgetInvalid('budget_invalid'),
  initializationCostExceeded('initialization_cost_exceeded'),
  memoryBudgetExceeded('memory_budget_exceeded'),
  storageBudgetExceeded('storage_budget_exceeded'),
  backgroundJobBudgetExceeded('background_job_budget_exceeded'),
  shutdownRequired('shutdown_required'),
  fallbackInvalid('fallback_invalid'),
  featureFlagMissing('feature_flag_missing');

  const ProductModuleLifecycleValidationCode(this.stableId);

  final String stableId;
}

enum ProductCompositionValidationCode {
  accepted('accepted'),
  profileManifestInvalid('profile_manifest_invalid'),
  duplicateLifecycleManifest('duplicate_lifecycle_manifest'),
  includedModuleNotCompiled('included_module_not_compiled'),
  excludedModuleCompiled('excluded_module_compiled'),
  includedModuleMissingLifecycle('included_module_missing_lifecycle'),
  lifecycleManifestInvalid('lifecycle_manifest_invalid'),
  lifecycleModuleNotCompiled('lifecycle_module_not_compiled'),
  fallbackModuleNotCompiled('fallback_module_not_compiled'),
  runtimeFlagUnsupported('runtime_flag_unsupported'),
  runtimeFlagWithoutModule('runtime_flag_without_module');

  const ProductCompositionValidationCode(this.stableId);

  final String stableId;
}

enum ProductCapabilityUnsupportedReasonCode {
  profileCapabilityAbsent('profile_capability_absent'),
  compositionInvalid('composition_invalid'),
  deviceRequirementBlocked('device_requirement_blocked'),
  moduleUnavailable('module_unavailable'),
  lifecycleInvalid('lifecycle_invalid');

  const ProductCapabilityUnsupportedReasonCode(this.stableId);

  final String stableId;
}

enum ProductCapability {
  directPlayback('direct_playback'),
  dpadNavigation('dpad_navigation'),
  companionRemote('companion_remote'),
  compactEpg('compact_epg'),
  fullEpg('full_epg'),
  basicSearch('basic_search'),
  diagnostics('diagnostics'),
  analytics('analytics'),
  localAi('local_ai'),
  recording('recording'),
  downloads('downloads'),
  multiview('multiview');

  const ProductCapability(this.stableId);

  final String stableId;
}

enum ProductModuleBackgroundTask {
  epgRefresh('epg_refresh'),
  searchIndexing('search_indexing'),
  recordingScheduler('recording_scheduler'),
  downloadWorker('download_worker'),
  diagnosticsUpload('diagnostics_upload'),
  analyticsFlush('analytics_flush'),
  modelWarmup('model_warmup');

  const ProductModuleBackgroundTask(this.stableId);

  final String stableId;
}

enum ProductModuleFeatureFlag {
  fullEpg('full_epg'),
  localAi('local_ai'),
  recording('recording'),
  downloads('downloads'),
  multiview('multiview'),
  diagnostics('diagnostics'),
  analytics('analytics');

  const ProductModuleFeatureFlag(this.stableId);

  final String stableId;
}

enum MediaCodecCapability {
  h264('h264'),
  aac('aac'),
  hls('hls'),
  mpegTs('mpeg_ts'),
  hevc('hevc'),
  av1('av1'),
  dolbyVision('dolby_vision');

  const MediaCodecCapability(this.stableId);

  final String stableId;
}

enum DeviceCapabilityBlocker {
  apiLevelTooLow('api_level_too_low'),
  memoryTooLow('memory_too_low'),
  storageTooLow('storage_too_low'),
  decoderCountTooLow('decoder_count_too_low'),
  requiredCodecMissing('required_codec_missing'),
  dpadRequired('dpad_required'),
  secureStorageRequired('secure_storage_required'),
  restrictedTrustRequired('restricted_trust_required');

  const DeviceCapabilityBlocker(this.stableId);

  final String stableId;
}

class ProductResourceBudget extends Equatable {
  const ProductResourceBudget({
    required this.maxMemoryMb,
    required this.maxStorageMb,
    required this.maxArtworkCacheMb,
    required this.maxBackgroundJobs,
  });

  final int maxMemoryMb;
  final int maxStorageMb;
  final int maxArtworkCacheMb;
  final int maxBackgroundJobs;

  @override
  List<Object?> get props => [
    maxMemoryMb,
    maxStorageMb,
    maxArtworkCacheMb,
    maxBackgroundJobs,
  ];
}

class ProductModuleLifecycleBudget extends Equatable {
  const ProductModuleLifecycleBudget({
    required this.initializationCostMs,
    required this.maxMemoryMb,
    required this.maxStorageMb,
    required this.maxBackgroundJobs,
  });

  final int initializationCostMs;
  final int maxMemoryMb;
  final int maxStorageMb;
  final int maxBackgroundJobs;

  @override
  List<Object?> get props => [
    initializationCostMs,
    maxMemoryMb,
    maxStorageMb,
    maxBackgroundJobs,
  ];
}

class ProductManifestValidationResult extends Equatable {
  ProductManifestValidationResult({
    required List<ProductManifestValidationCode> codes,
  }) : codes = List.unmodifiable(codes);

  final List<ProductManifestValidationCode> codes;

  bool get accepted =>
      codes.length == 1 &&
      codes.single == ProductManifestValidationCode.accepted;

  Map<String, Object?> toPublicMap() {
    return {
      'accepted': accepted,
      'codes': _manifestValidationCodeStableIds(codes),
    };
  }

  @override
  List<Object?> get props => [codes];
}

class ProductModuleLifecycleValidationResult extends Equatable {
  ProductModuleLifecycleValidationResult({
    required List<ProductModuleLifecycleValidationCode> codes,
  }) : codes = List.unmodifiable(codes);

  final List<ProductModuleLifecycleValidationCode> codes;

  bool get accepted =>
      codes.length == 1 &&
      codes.single == ProductModuleLifecycleValidationCode.accepted;

  Map<String, Object?> toPublicMap() {
    return {
      'accepted': accepted,
      'codes': _moduleLifecycleValidationCodeStableIds(codes),
    };
  }

  @override
  List<Object?> get props => [codes];
}

class ProductCompositionValidationResult extends Equatable {
  ProductCompositionValidationResult({
    required List<ProductCompositionValidationCode> codes,
    required this.profileValidation,
    required Map<ProductModule, ProductModuleLifecycleValidationResult>
    lifecycleValidations,
  }) : codes = List.unmodifiable(codes),
       lifecycleValidations = Map.unmodifiable(lifecycleValidations);

  final List<ProductCompositionValidationCode> codes;
  final ProductManifestValidationResult profileValidation;
  final Map<ProductModule, ProductModuleLifecycleValidationResult>
  lifecycleValidations;

  bool get accepted =>
      codes.length == 1 &&
      codes.single == ProductCompositionValidationCode.accepted;

  Map<String, Object?> toPublicMap() {
    return {
      'accepted': accepted,
      'codes': _compositionValidationCodeStableIds(codes),
      'profileValidation': profileValidation.toPublicMap(),
      'lifecycleValidations': lifecycleValidations.map(
        (module, result) => MapEntry(module.stableId, result.toPublicMap()),
      ),
    };
  }

  @override
  List<Object?> get props => [codes, profileValidation, lifecycleValidations];
}

class ProductCapabilityUnsupportedReason extends Equatable {
  ProductCapabilityUnsupportedReason({
    required this.code,
    this.capability,
    this.module,
    this.deviceBlocker,
    this.compositionCode,
    List<ProductModuleLifecycleValidationCode> lifecycleCodes = const [],
  }) : lifecycleCodes = List.unmodifiable(lifecycleCodes);

  final ProductCapabilityUnsupportedReasonCode code;
  final ProductCapability? capability;
  final ProductModule? module;
  final DeviceCapabilityBlocker? deviceBlocker;
  final ProductCompositionValidationCode? compositionCode;
  final List<ProductModuleLifecycleValidationCode> lifecycleCodes;

  Map<String, Object?> toPublicMap() {
    return {
      'code': code.stableId,
      'capability': capability?.stableId,
      'module': module?.stableId,
      'deviceBlocker': deviceBlocker?.stableId,
      'compositionCode': compositionCode?.stableId,
      'lifecycleCodes': _moduleLifecycleValidationCodeStableIds(lifecycleCodes),
    };
  }

  @override
  List<Object?> get props => [
    code,
    capability,
    module,
    deviceBlocker,
    compositionCode,
    lifecycleCodes,
  ];
}

class ProductCapabilityAdvertisement extends Equatable {
  ProductCapabilityAdvertisement({
    required this.profileId,
    required this.supportLevel,
    required this.releaseChannel,
    required Set<ProductModule> compiledModules,
    required Set<ProductCapability> runtimeSafeCapabilities,
    required Set<ProductProfileGuarantee> guarantees,
    required Set<ProductModuleFeatureFlag> enabledFeatureFlags,
    required List<ProductCapabilityUnsupportedReason> unsupportedReasons,
    required this.compositionAccepted,
    required this.deviceSupported,
    this.schemaVersion = kProductCapabilitiesSchemaVersion,
  }) : compiledModules = Set.unmodifiable(compiledModules),
       runtimeSafeCapabilities = Set.unmodifiable(runtimeSafeCapabilities),
       guarantees = Set.unmodifiable(guarantees),
       enabledFeatureFlags = Set.unmodifiable(enabledFeatureFlags),
       unsupportedReasons = List.unmodifiable(unsupportedReasons);

  final String schemaVersion;
  final ProductProfileId profileId;
  final ProductSupportLevel supportLevel;
  final ProductReleaseChannel releaseChannel;
  final Set<ProductModule> compiledModules;
  final Set<ProductCapability> runtimeSafeCapabilities;
  final Set<ProductProfileGuarantee> guarantees;
  final Set<ProductModuleFeatureFlag> enabledFeatureFlags;
  final List<ProductCapabilityUnsupportedReason> unsupportedReasons;
  final bool compositionAccepted;
  final bool deviceSupported;

  bool advertises(ProductCapability capability) {
    return runtimeSafeCapabilities.contains(capability);
  }

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'profileId': profileId.stableId,
      'supportLevel': supportLevel.stableId,
      'releaseChannel': releaseChannel.stableId,
      'compiledModules': _productModuleStableIds(compiledModules),
      'runtimeSafeCapabilities': _productCapabilityStableIds(
        runtimeSafeCapabilities,
      ),
      'guarantees': _productGuaranteeStableIds(guarantees),
      'enabledFeatureFlags': _moduleFeatureFlagStableIds(enabledFeatureFlags),
      'compositionAccepted': compositionAccepted,
      'deviceSupported': deviceSupported,
      'unsupportedReasons': unsupportedReasons
          .map((reason) => reason.toPublicMap())
          .toList(growable: false),
    };
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    profileId,
    supportLevel,
    releaseChannel,
    compiledModules,
    runtimeSafeCapabilities,
    guarantees,
    enabledFeatureFlags,
    unsupportedReasons,
    compositionAccepted,
    deviceSupported,
  ];
}

class DeviceCapabilitySnapshot extends Equatable {
  DeviceCapabilitySnapshot({
    required this.apiLevel,
    required this.memoryMb,
    required this.freeStorageMb,
    required this.decoderCount,
    required Set<MediaCodecCapability> supportedCodecs,
    required this.hasDpad,
    required this.hasSecureStorage,
    this.requiresRestrictedTrust = false,
    this.schemaVersion = kProductCapabilitiesSchemaVersion,
  }) : supportedCodecs = Set.unmodifiable(supportedCodecs);

  final String schemaVersion;
  final int apiLevel;
  final int memoryMb;
  final int freeStorageMb;
  final int decoderCount;
  final Set<MediaCodecCapability> supportedCodecs;
  final bool hasDpad;
  final bool hasSecureStorage;
  final bool requiresRestrictedTrust;

  @override
  List<Object?> get props => [
    schemaVersion,
    apiLevel,
    memoryMb,
    freeStorageMb,
    decoderCount,
    supportedCodecs,
    hasDpad,
    hasSecureStorage,
    requiresRestrictedTrust,
  ];
}

class DeviceCapabilityRequirement extends Equatable {
  DeviceCapabilityRequirement({
    required this.minApiLevel,
    required this.minMemoryMb,
    required this.minFreeStorageMb,
    required this.minDecoderCount,
    required Set<MediaCodecCapability> requiredCodecs,
    this.requiresDpad = true,
    this.requiresSecureStorage = true,
    this.allowsRestrictedTrust = true,
  }) : requiredCodecs = Set.unmodifiable(requiredCodecs);

  final int minApiLevel;
  final int minMemoryMb;
  final int minFreeStorageMb;
  final int minDecoderCount;
  final Set<MediaCodecCapability> requiredCodecs;
  final bool requiresDpad;
  final bool requiresSecureStorage;
  final bool allowsRestrictedTrust;

  DeviceCapabilityEvaluation evaluate(DeviceCapabilitySnapshot snapshot) {
    final blockers = <DeviceCapabilityBlocker>[];

    if (snapshot.apiLevel < minApiLevel) {
      blockers.add(DeviceCapabilityBlocker.apiLevelTooLow);
    }
    if (snapshot.memoryMb < minMemoryMb) {
      blockers.add(DeviceCapabilityBlocker.memoryTooLow);
    }
    if (snapshot.freeStorageMb < minFreeStorageMb) {
      blockers.add(DeviceCapabilityBlocker.storageTooLow);
    }
    if (snapshot.decoderCount < minDecoderCount) {
      blockers.add(DeviceCapabilityBlocker.decoderCountTooLow);
    }
    if (!snapshot.supportedCodecs.containsAll(requiredCodecs)) {
      blockers.add(DeviceCapabilityBlocker.requiredCodecMissing);
    }
    if (requiresDpad && !snapshot.hasDpad) {
      blockers.add(DeviceCapabilityBlocker.dpadRequired);
    }
    if (requiresSecureStorage && !snapshot.hasSecureStorage) {
      blockers.add(DeviceCapabilityBlocker.secureStorageRequired);
    }
    if (!allowsRestrictedTrust && snapshot.requiresRestrictedTrust) {
      blockers.add(DeviceCapabilityBlocker.restrictedTrustRequired);
    }

    return DeviceCapabilityEvaluation(blockers: blockers);
  }

  @override
  List<Object?> get props => [
    minApiLevel,
    minMemoryMb,
    minFreeStorageMb,
    minDecoderCount,
    requiredCodecs,
    requiresDpad,
    requiresSecureStorage,
    allowsRestrictedTrust,
  ];
}

class DeviceCapabilityEvaluation extends Equatable {
  DeviceCapabilityEvaluation({required List<DeviceCapabilityBlocker> blockers})
    : blockers = List.unmodifiable(blockers);

  final List<DeviceCapabilityBlocker> blockers;

  bool get isSupported => blockers.isEmpty;

  @override
  List<Object?> get props => [blockers];
}

class ProductProfileManifest extends Equatable {
  ProductProfileManifest({
    required this.profileId,
    required this.displayName,
    required this.supportLevel,
    this.releaseChannel = ProductReleaseChannel.internalCertification,
    required this.resourceBudget,
    required this.deviceRequirement,
    required Set<ProductModule> includedModules,
    required Set<ProductModule> excludedModules,
    required Set<ProductCapability> capabilities,
    required List<ProductNavigationEntry> navigation,
    required Set<String> androidPermissions,
    Set<ProductProfileGuarantee> guarantees = const {},
    this.schemaVersion = kProductCapabilitiesSchemaVersion,
  }) : includedModules = Set.unmodifiable(includedModules),
       excludedModules = Set.unmodifiable(excludedModules),
       capabilities = Set.unmodifiable(capabilities),
       navigation = List.unmodifiable(navigation),
       androidPermissions = Set.unmodifiable(androidPermissions),
       guarantees = Set.unmodifiable(guarantees);

  final String schemaVersion;
  final ProductProfileId profileId;
  final String displayName;
  final ProductSupportLevel supportLevel;
  final ProductReleaseChannel releaseChannel;
  final Set<ProductModule> includedModules;
  final Set<ProductModule> excludedModules;
  final Set<ProductCapability> capabilities;
  final List<ProductNavigationEntry> navigation;
  final Set<String> androidPermissions;
  final Set<ProductProfileGuarantee> guarantees;
  final ProductResourceBudget resourceBudget;
  final DeviceCapabilityRequirement deviceRequirement;

  bool includesModule(ProductModule module) =>
      includedModules.contains(module) && !excludedModules.contains(module);

  bool supportsCapability(ProductCapability capability) =>
      capabilities.contains(capability);

  DeviceCapabilityEvaluation evaluateDevice(
    DeviceCapabilitySnapshot snapshot,
  ) => deviceRequirement.evaluate(snapshot);

  ProductManifestValidationResult validate() {
    return ProductProfileManifestPolicy().evaluate(this);
  }

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'profileId': profileId.stableId,
      'displayName': displayName,
      'supportLevel': supportLevel.stableId,
      'releaseChannel': releaseChannel.stableId,
      'includedModules': _productModuleStableIds(includedModules),
      'excludedModules': _productModuleStableIds(excludedModules),
      'capabilities': _productCapabilityStableIds(capabilities),
      'navigation': navigation
          .map((entry) => entry.stableId)
          .toList(growable: false),
      'androidPermissions': androidPermissions.toList(growable: false)..sort(),
      'guarantees': _productGuaranteeStableIds(guarantees),
      'resourceBudget': {
        'maxMemoryMb': resourceBudget.maxMemoryMb,
        'maxStorageMb': resourceBudget.maxStorageMb,
        'maxArtworkCacheMb': resourceBudget.maxArtworkCacheMb,
        'maxBackgroundJobs': resourceBudget.maxBackgroundJobs,
      },
      'deviceRequirement': {
        'minApiLevel': deviceRequirement.minApiLevel,
        'minMemoryMb': deviceRequirement.minMemoryMb,
        'minFreeStorageMb': deviceRequirement.minFreeStorageMb,
        'minDecoderCount': deviceRequirement.minDecoderCount,
        'requiredCodecs': _mediaCodecStableIds(
          deviceRequirement.requiredCodecs,
        ),
        'requiresDpad': deviceRequirement.requiresDpad,
        'requiresSecureStorage': deviceRequirement.requiresSecureStorage,
        'allowsRestrictedTrust': deviceRequirement.allowsRestrictedTrust,
      },
    };
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    profileId,
    displayName,
    supportLevel,
    releaseChannel,
    includedModules,
    excludedModules,
    capabilities,
    navigation,
    androidPermissions,
    guarantees,
    resourceBudget,
    deviceRequirement,
  ];
}

class ProductProfileManifestPolicy extends Equatable {
  ProductProfileManifestPolicy({
    Set<String> allowedAndroidPermissions = const {
      'android.permission.INTERNET',
      'android.permission.ACCESS_NETWORK_STATE',
      'android.permission.RECORD_AUDIO',
      'android.permission.POST_NOTIFICATIONS',
    },
  }) : allowedAndroidPermissions = Set.unmodifiable(allowedAndroidPermissions);

  final Set<String> allowedAndroidPermissions;

  ProductManifestValidationResult evaluate(ProductProfileManifest manifest) {
    final codes = <ProductManifestValidationCode>[];
    if (manifest.includedModules
        .intersection(manifest.excludedModules)
        .isNotEmpty) {
      codes.add(ProductManifestValidationCode.moduleOverlap);
    }
    if (manifest.resourceBudget.maxMemoryMb <= 0 ||
        manifest.resourceBudget.maxStorageMb <= 0 ||
        manifest.resourceBudget.maxArtworkCacheMb < 0 ||
        manifest.resourceBudget.maxBackgroundJobs < 0) {
      codes.add(ProductManifestValidationCode.budgetInvalid);
    }
    if (!allowedAndroidPermissions.containsAll(manifest.androidPermissions)) {
      codes.add(ProductManifestValidationCode.permissionUnsupported);
    }
    if (manifest.navigation.any(
      (entry) => !_navigationSupportedByManifest(entry, manifest),
    )) {
      codes.add(ProductManifestValidationCode.navigationUnsupported);
    }
    if (manifest.capabilities.any(
      (capability) => !_capabilitySupportedByManifest(capability, manifest),
    )) {
      codes.add(ProductManifestValidationCode.capabilityUnsupported);
    }
    if (!_releaseChannelMatchesProfile(manifest)) {
      codes.add(ProductManifestValidationCode.releaseChannelMismatch);
    }
    if (!_supportLevelMatchesChannel(manifest)) {
      codes.add(ProductManifestValidationCode.supportLevelMismatch);
    }

    return ProductManifestValidationResult(
      codes: codes.isEmpty
          ? const [ProductManifestValidationCode.accepted]
          : codes,
    );
  }

  bool _navigationSupportedByManifest(
    ProductNavigationEntry entry,
    ProductProfileManifest manifest,
  ) {
    return switch (entry) {
      ProductNavigationEntry.home || ProductNavigationEntry.settings => true,
      ProductNavigationEntry.live => manifest.includesModule(
        ProductModule.playback,
      ),
      ProductNavigationEntry.guide =>
        manifest.includesModule(ProductModule.compactEpg) ||
            manifest.includesModule(ProductModule.fullEpg),
      ProductNavigationEntry.favorites => manifest.includesModule(
        ProductModule.favorites,
      ),
      ProductNavigationEntry.recent => manifest.includesModule(
        ProductModule.recent,
      ),
      ProductNavigationEntry.search => manifest.includesModule(
        ProductModule.basicSearch,
      ),
      ProductNavigationEntry.diagnostics => manifest.includesModule(
        ProductModule.diagnostics,
      ),
      ProductNavigationEntry.profiles =>
        manifest.profileId == ProductProfileId.fullTv,
    };
  }

  bool _capabilitySupportedByManifest(
    ProductCapability capability,
    ProductProfileManifest manifest,
  ) {
    return switch (capability) {
      ProductCapability.directPlayback => manifest.includesModule(
        ProductModule.playback,
      ),
      ProductCapability.dpadNavigation => true,
      ProductCapability.companionRemote => manifest.includesModule(
        ProductModule.remoteControl,
      ),
      ProductCapability.compactEpg => manifest.includesModule(
        ProductModule.compactEpg,
      ),
      ProductCapability.fullEpg => manifest.includesModule(
        ProductModule.fullEpg,
      ),
      ProductCapability.basicSearch => manifest.includesModule(
        ProductModule.basicSearch,
      ),
      ProductCapability.diagnostics => manifest.includesModule(
        ProductModule.diagnostics,
      ),
      ProductCapability.analytics => manifest.includesModule(
        ProductModule.analytics,
      ),
      ProductCapability.localAi => manifest.includesModule(
        ProductModule.localAi,
      ),
      ProductCapability.recording => manifest.includesModule(
        ProductModule.recording,
      ),
      ProductCapability.downloads => manifest.includesModule(
        ProductModule.downloads,
      ),
      ProductCapability.multiview => manifest.includesModule(
        ProductModule.multiview,
      ),
    };
  }

  bool _releaseChannelMatchesProfile(ProductProfileManifest manifest) {
    return switch (manifest.releaseChannel) {
      ProductReleaseChannel.fullTvStable =>
        manifest.profileId == ProductProfileId.fullTv ||
            manifest.profileId == ProductProfileId.standardTv,
      ProductReleaseChannel.liteReceiverStable ||
      ProductReleaseChannel.receiverStable =>
        manifest.profileId == ProductProfileId.liteReceiver ||
            manifest.profileId == ProductProfileId.embeddedReceiver,
      ProductReleaseChannel.legacyExperimental =>
        manifest.profileId == ProductProfileId.experimentalLegacy,
      ProductReleaseChannel.vendorSpecific ||
      ProductReleaseChannel.internalCertification => true,
    };
  }

  bool _supportLevelMatchesChannel(ProductProfileManifest manifest) {
    return switch (manifest.releaseChannel) {
      ProductReleaseChannel.legacyExperimental =>
        manifest.supportLevel == ProductSupportLevel.experimental,
      ProductReleaseChannel.fullTvStable ||
      ProductReleaseChannel.liteReceiverStable ||
      ProductReleaseChannel.receiverStable =>
        manifest.supportLevel == ProductSupportLevel.certified ||
            manifest.supportLevel == ProductSupportLevel.compatible,
      ProductReleaseChannel.vendorSpecific ||
      ProductReleaseChannel.internalCertification =>
        manifest.supportLevel != ProductSupportLevel.unsupported,
    };
  }

  @override
  List<Object?> get props => [allowedAndroidPermissions];
}

class ProductModuleLifecycleManifest extends Equatable {
  ProductModuleLifecycleManifest({
    required this.module,
    required this.displayName,
    required Set<ProductProfileId> supportedProfiles,
    required Set<ProductModule> dependencies,
    required Set<ProductCapability> requiredCapabilities,
    required Set<String> androidPermissions,
    required this.budget,
    Set<ProductModuleBackgroundTask> backgroundTasks = const {},
    Set<ProductModuleFeatureFlag> featureFlags = const {},
    this.fallbackModule,
    this.allowsBackgroundExecution = false,
    this.supportsGracefulShutdown = true,
    this.schemaVersion = kProductCapabilitiesSchemaVersion,
  }) : supportedProfiles = Set.unmodifiable(supportedProfiles),
       dependencies = Set.unmodifiable(dependencies),
       requiredCapabilities = Set.unmodifiable(requiredCapabilities),
       androidPermissions = Set.unmodifiable(androidPermissions),
       backgroundTasks = Set.unmodifiable(backgroundTasks),
       featureFlags = Set.unmodifiable(featureFlags);

  final String schemaVersion;
  final ProductModule module;
  final String displayName;
  final Set<ProductProfileId> supportedProfiles;
  final Set<ProductModule> dependencies;
  final Set<ProductCapability> requiredCapabilities;
  final Set<String> androidPermissions;
  final ProductModuleLifecycleBudget budget;
  final Set<ProductModuleBackgroundTask> backgroundTasks;
  final Set<ProductModuleFeatureFlag> featureFlags;
  final ProductModule? fallbackModule;
  final bool allowsBackgroundExecution;
  final bool supportsGracefulShutdown;

  bool supportsProfile(ProductProfileId profileId) {
    return supportedProfiles.contains(profileId);
  }

  ProductModuleLifecycleValidationResult validateFor(
    ProductProfileManifest profile,
  ) {
    return ProductModuleLifecyclePolicy().evaluate(this, profile);
  }

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'module': module.stableId,
      'displayName': displayName,
      'supportedProfiles': _productProfileStableIds(supportedProfiles),
      'dependencies': _productModuleStableIds(dependencies),
      'requiredCapabilities': _productCapabilityStableIds(requiredCapabilities),
      'androidPermissions': androidPermissions.toList(growable: false)..sort(),
      'budget': {
        'initializationCostMs': budget.initializationCostMs,
        'maxMemoryMb': budget.maxMemoryMb,
        'maxStorageMb': budget.maxStorageMb,
        'maxBackgroundJobs': budget.maxBackgroundJobs,
      },
      'backgroundTasks': _moduleBackgroundTaskStableIds(backgroundTasks),
      'featureFlags': _moduleFeatureFlagStableIds(featureFlags),
      'fallbackModule': fallbackModule?.stableId,
      'allowsBackgroundExecution': allowsBackgroundExecution,
      'supportsGracefulShutdown': supportsGracefulShutdown,
    };
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    module,
    displayName,
    supportedProfiles,
    dependencies,
    requiredCapabilities,
    androidPermissions,
    budget,
    backgroundTasks,
    featureFlags,
    fallbackModule,
    allowsBackgroundExecution,
    supportsGracefulShutdown,
  ];
}

class ProductModuleLifecyclePolicy extends Equatable {
  ProductModuleLifecyclePolicy({
    Map<ProductProfileId, int> maxInitializationCostMsByProfile = const {
      ProductProfileId.fullTv: 3000,
      ProductProfileId.standardTv: 2000,
      ProductProfileId.liteReceiver: 900,
      ProductProfileId.embeddedReceiver: 900,
      ProductProfileId.experimentalLegacy: 1500,
    },
  }) : maxInitializationCostMsByProfile = Map.unmodifiable(
         maxInitializationCostMsByProfile,
       );

  final Map<ProductProfileId, int> maxInitializationCostMsByProfile;

  ProductModuleLifecycleValidationResult evaluate(
    ProductModuleLifecycleManifest manifest,
    ProductProfileManifest profile,
  ) {
    final codes = <ProductModuleLifecycleValidationCode>[];
    final requiredFlag = _requiredFeatureFlag(manifest.module);

    if (!manifest.supportsProfile(profile.profileId)) {
      codes.add(ProductModuleLifecycleValidationCode.unsupportedProfile);
    }
    if (!profile.includesModule(manifest.module)) {
      codes.add(ProductModuleLifecycleValidationCode.moduleUnavailable);
    }
    if (manifest.dependencies.any(
      (module) => !profile.includesModule(module),
    )) {
      codes.add(ProductModuleLifecycleValidationCode.dependencyMissing);
    }
    if (manifest.requiredCapabilities.any(
      (capability) => !profile.supportsCapability(capability),
    )) {
      codes.add(ProductModuleLifecycleValidationCode.capabilityUnsupported);
    }
    if (!profile.androidPermissions.containsAll(manifest.androidPermissions)) {
      codes.add(ProductModuleLifecycleValidationCode.permissionUnsupported);
    }
    if (manifest.budget.initializationCostMs <= 0 ||
        manifest.budget.maxMemoryMb <= 0 ||
        manifest.budget.maxStorageMb < 0 ||
        manifest.budget.maxBackgroundJobs < 0) {
      codes.add(ProductModuleLifecycleValidationCode.budgetInvalid);
    }
    if (manifest.budget.initializationCostMs >
        (maxInitializationCostMsByProfile[profile.profileId] ?? 0)) {
      codes.add(
        ProductModuleLifecycleValidationCode.initializationCostExceeded,
      );
    }
    if (manifest.budget.maxMemoryMb > profile.resourceBudget.maxMemoryMb) {
      codes.add(ProductModuleLifecycleValidationCode.memoryBudgetExceeded);
    }
    if (manifest.budget.maxStorageMb > profile.resourceBudget.maxStorageMb) {
      codes.add(ProductModuleLifecycleValidationCode.storageBudgetExceeded);
    }
    if (manifest.budget.maxBackgroundJobs >
            profile.resourceBudget.maxBackgroundJobs ||
        manifest.backgroundTasks.length >
            profile.resourceBudget.maxBackgroundJobs) {
      codes.add(
        ProductModuleLifecycleValidationCode.backgroundJobBudgetExceeded,
      );
    }
    if (manifest.backgroundTasks.isNotEmpty &&
        (!manifest.allowsBackgroundExecution ||
            !manifest.supportsGracefulShutdown)) {
      codes.add(ProductModuleLifecycleValidationCode.shutdownRequired);
    }
    if (manifest.fallbackModule == manifest.module ||
        (manifest.fallbackModule != null &&
            !profile.includesModule(manifest.fallbackModule!))) {
      codes.add(ProductModuleLifecycleValidationCode.fallbackInvalid);
    }
    if (requiredFlag != null && !manifest.featureFlags.contains(requiredFlag)) {
      codes.add(ProductModuleLifecycleValidationCode.featureFlagMissing);
    }

    return ProductModuleLifecycleValidationResult(
      codes: codes.isEmpty
          ? const [ProductModuleLifecycleValidationCode.accepted]
          : codes,
    );
  }

  ProductModuleFeatureFlag? _requiredFeatureFlag(ProductModule module) {
    return switch (module) {
      ProductModule.fullEpg => ProductModuleFeatureFlag.fullEpg,
      ProductModule.localAi => ProductModuleFeatureFlag.localAi,
      ProductModule.recording => ProductModuleFeatureFlag.recording,
      ProductModule.downloads => ProductModuleFeatureFlag.downloads,
      ProductModule.multiview => ProductModuleFeatureFlag.multiview,
      ProductModule.diagnostics => ProductModuleFeatureFlag.diagnostics,
      ProductModule.analytics => ProductModuleFeatureFlag.analytics,
      ProductModule.playback ||
      ProductModule.playlistImport ||
      ProductModule.favorites ||
      ProductModule.recent ||
      ProductModule.basicSearch ||
      ProductModule.compactEpg ||
      ProductModule.pairing ||
      ProductModule.remoteControl => null,
    };
  }

  @override
  List<Object?> get props => [maxInitializationCostMsByProfile];
}

class ProductCompositionManifest extends Equatable {
  ProductCompositionManifest({
    required this.profileManifest,
    required Set<ProductModule> compiledModules,
    required List<ProductModuleLifecycleManifest> lifecycleManifests,
    Set<ProductModuleFeatureFlag> enabledFeatureFlags = const {},
    this.schemaVersion = kProductCapabilitiesSchemaVersion,
  }) : compiledModules = Set.unmodifiable(compiledModules),
       lifecycleManifests = List.unmodifiable(lifecycleManifests),
       enabledFeatureFlags = Set.unmodifiable(enabledFeatureFlags);

  final String schemaVersion;
  final ProductProfileManifest profileManifest;
  final Set<ProductModule> compiledModules;
  final List<ProductModuleLifecycleManifest> lifecycleManifests;
  final Set<ProductModuleFeatureFlag> enabledFeatureFlags;

  ProductCompositionValidationResult validate() {
    return ProductCompositionPolicy().evaluate(this);
  }

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'profile': profileManifest.toPublicMap(),
      'compiledModules': _productModuleStableIds(compiledModules),
      'enabledFeatureFlags': _moduleFeatureFlagStableIds(enabledFeatureFlags),
      'lifecycleModules': _productModuleStableIds(
        lifecycleManifests.map((manifest) => manifest.module),
      ),
    };
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    profileManifest,
    compiledModules,
    lifecycleManifests,
    enabledFeatureFlags,
  ];
}

class ProductCompositionPolicy extends Equatable {
  const ProductCompositionPolicy();

  ProductCompositionValidationResult evaluate(
    ProductCompositionManifest composition,
  ) {
    final codes = <ProductCompositionValidationCode>[];
    final profile = composition.profileManifest;
    final profileValidation = profile.validate();
    final lifecycleValidations =
        <ProductModule, ProductModuleLifecycleValidationResult>{};
    final lifecycleByModule = <ProductModule, ProductModuleLifecycleManifest>{};
    final duplicateLifecycleModules = <ProductModule>{};

    if (!profileValidation.accepted) {
      codes.add(ProductCompositionValidationCode.profileManifestInvalid);
    }

    for (final lifecycle in composition.lifecycleManifests) {
      if (lifecycleByModule.containsKey(lifecycle.module)) {
        duplicateLifecycleModules.add(lifecycle.module);
      }
      lifecycleByModule[lifecycle.module] = lifecycle;
    }
    if (duplicateLifecycleModules.isNotEmpty) {
      codes.add(ProductCompositionValidationCode.duplicateLifecycleManifest);
    }

    for (final module in profile.includedModules) {
      if (!composition.compiledModules.contains(module)) {
        codes.add(ProductCompositionValidationCode.includedModuleNotCompiled);
        break;
      }
    }

    for (final module in profile.excludedModules) {
      if (composition.compiledModules.contains(module)) {
        codes.add(ProductCompositionValidationCode.excludedModuleCompiled);
        break;
      }
    }

    for (final module in profile.includedModules) {
      if (!lifecycleByModule.containsKey(module)) {
        codes.add(
          ProductCompositionValidationCode.includedModuleMissingLifecycle,
        );
        break;
      }
    }

    for (final lifecycle in composition.lifecycleManifests) {
      final result = lifecycle.validateFor(profile);
      lifecycleValidations[lifecycle.module] = result;
      if (!result.accepted) {
        codes.add(ProductCompositionValidationCode.lifecycleManifestInvalid);
      }
      if (!composition.compiledModules.contains(lifecycle.module)) {
        codes.add(ProductCompositionValidationCode.lifecycleModuleNotCompiled);
      }
      final fallbackModule = lifecycle.fallbackModule;
      if (fallbackModule != null &&
          !composition.compiledModules.contains(fallbackModule)) {
        codes.add(ProductCompositionValidationCode.fallbackModuleNotCompiled);
      }
    }

    for (final featureFlag in composition.enabledFeatureFlags) {
      final matchingLifecycle = composition.lifecycleManifests
          .where((manifest) => manifest.featureFlags.contains(featureFlag))
          .toList(growable: false);
      if (matchingLifecycle.isEmpty) {
        codes.add(ProductCompositionValidationCode.runtimeFlagUnsupported);
        continue;
      }
      if (matchingLifecycle.any(
        (manifest) =>
            !composition.compiledModules.contains(manifest.module) ||
            !profile.includesModule(manifest.module),
      )) {
        codes.add(ProductCompositionValidationCode.runtimeFlagWithoutModule);
      }
    }

    return ProductCompositionValidationResult(
      codes: codes.isEmpty
          ? const [ProductCompositionValidationCode.accepted]
          : codes.toSet().toList(growable: false),
      profileValidation: profileValidation,
      lifecycleValidations: lifecycleValidations,
    );
  }

  @override
  List<Object?> get props => const [];
}

class ProductCapabilityAdvertisementPolicy extends Equatable {
  const ProductCapabilityAdvertisementPolicy();

  ProductCapabilityAdvertisement publish({
    required ProductCompositionManifest composition,
    required DeviceCapabilitySnapshot deviceSnapshot,
  }) {
    final profile = composition.profileManifest;
    final compositionResult = composition.validate();
    final deviceEvaluation = profile.evaluateDevice(deviceSnapshot);
    final runtimeSafeCapabilities = <ProductCapability>{};
    final unsupportedReasons = <ProductCapabilityUnsupportedReason>[];

    if (!compositionResult.accepted) {
      for (final code in compositionResult.codes) {
        unsupportedReasons.add(
          ProductCapabilityUnsupportedReason(
            code: ProductCapabilityUnsupportedReasonCode.compositionInvalid,
            compositionCode: code,
          ),
        );
      }
    }

    if (!deviceEvaluation.isSupported) {
      for (final blocker in deviceEvaluation.blockers) {
        unsupportedReasons.add(
          ProductCapabilityUnsupportedReason(
            code:
                ProductCapabilityUnsupportedReasonCode.deviceRequirementBlocked,
            deviceBlocker: blocker,
          ),
        );
      }
    }

    for (final capability in ProductCapability.values) {
      if (!profile.supportsCapability(capability)) {
        unsupportedReasons.add(
          ProductCapabilityUnsupportedReason(
            code:
                ProductCapabilityUnsupportedReasonCode.profileCapabilityAbsent,
            capability: capability,
            module: _moduleForCapability(capability),
          ),
        );
        continue;
      }

      if (!deviceEvaluation.isSupported ||
          !compositionResult.profileValidation.accepted) {
        continue;
      }

      final module = _moduleForCapability(capability);
      if (module == null) {
        runtimeSafeCapabilities.add(capability);
        continue;
      }

      if (!profile.includesModule(module) ||
          !composition.compiledModules.contains(module)) {
        unsupportedReasons.add(
          ProductCapabilityUnsupportedReason(
            code: ProductCapabilityUnsupportedReasonCode.moduleUnavailable,
            capability: capability,
            module: module,
          ),
        );
        continue;
      }

      final lifecycleResult = compositionResult.lifecycleValidations[module];
      if (lifecycleResult == null || !lifecycleResult.accepted) {
        unsupportedReasons.add(
          ProductCapabilityUnsupportedReason(
            code: ProductCapabilityUnsupportedReasonCode.lifecycleInvalid,
            capability: capability,
            module: module,
            lifecycleCodes: lifecycleResult?.codes ?? const [],
          ),
        );
        continue;
      }

      runtimeSafeCapabilities.add(capability);
    }

    return ProductCapabilityAdvertisement(
      profileId: profile.profileId,
      supportLevel: profile.supportLevel,
      releaseChannel: profile.releaseChannel,
      compiledModules: composition.compiledModules,
      runtimeSafeCapabilities: runtimeSafeCapabilities,
      guarantees: profile.guarantees,
      enabledFeatureFlags: composition.enabledFeatureFlags,
      unsupportedReasons: unsupportedReasons,
      compositionAccepted: compositionResult.accepted,
      deviceSupported: deviceEvaluation.isSupported,
    );
  }

  @override
  List<Object?> get props => const [];
}

class ProductNavigationSection extends Equatable {
  const ProductNavigationSection({
    required this.entry,
    required this.routeId,
    required this.displayKey,
    required this.renderTier,
    this.requiredModule,
    this.requiredCapability,
  });

  final ProductNavigationEntry entry;
  final String routeId;
  final String displayKey;
  final ProductNavigationRenderTier renderTier;
  final ProductModule? requiredModule;
  final ProductCapability? requiredCapability;

  Map<String, Object?> toPublicMap() {
    return {
      'entry': entry.stableId,
      'routeId': routeId,
      'displayKey': displayKey,
      'renderTier': renderTier.stableId,
      'requiredModule': requiredModule?.stableId,
      'requiredCapability': requiredCapability?.stableId,
    };
  }

  @override
  List<Object?> get props => [
    entry,
    routeId,
    displayKey,
    renderTier,
    requiredModule,
    requiredCapability,
  ];
}

class ProductNavigationManifest extends Equatable {
  ProductNavigationManifest({
    required this.profileId,
    required List<ProductNavigationSection> sections,
    this.schemaVersion = kProductCapabilitiesSchemaVersion,
  }) : sections = List.unmodifiable(sections);

  final String schemaVersion;
  final ProductProfileId profileId;
  final List<ProductNavigationSection> sections;

  List<ProductNavigationValidationCode> validate({
    required ProductProfileManifest profile,
    ProductCompositionManifest? composition,
  }) {
    return ProductNavigationManifestPolicy().evaluate(
      manifest: this,
      profile: profile,
      composition: composition,
    );
  }

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'profileId': profileId.stableId,
      'sections': sections
          .map((section) => section.toPublicMap())
          .toList(growable: false),
    };
  }

  @override
  List<Object?> get props => [schemaVersion, profileId, sections];
}

class ProductNavigationManifestPolicy extends Equatable {
  const ProductNavigationManifestPolicy();

  List<ProductNavigationValidationCode> evaluate({
    required ProductNavigationManifest manifest,
    required ProductProfileManifest profile,
    ProductCompositionManifest? composition,
  }) {
    final codes = <ProductNavigationValidationCode>[];
    final routeIds = <String>{};

    if (manifest.profileId != profile.profileId) {
      codes.add(ProductNavigationValidationCode.profileMismatch);
    }

    for (final section in manifest.sections) {
      final routeId = section.routeId.trim();
      if (routeId.isEmpty) {
        codes.add(ProductNavigationValidationCode.routeIdMissing);
      } else if (!routeIds.add(routeId)) {
        codes.add(ProductNavigationValidationCode.duplicateRouteId);
      }
      if (section.displayKey.trim().isEmpty) {
        codes.add(ProductNavigationValidationCode.displayKeyMissing);
      }
      if (!profile.navigation.contains(section.entry)) {
        codes.add(ProductNavigationValidationCode.entryUnsupported);
      }
      final requiredModule = section.requiredModule;
      if (requiredModule != null && !profile.includesModule(requiredModule)) {
        codes.add(ProductNavigationValidationCode.moduleUnavailable);
      }
      final requiredCapability = section.requiredCapability;
      if (requiredCapability != null &&
          !profile.supportsCapability(requiredCapability)) {
        codes.add(ProductNavigationValidationCode.capabilityUnsupported);
      }
      if (requiredModule != null &&
          composition != null &&
          !composition.compiledModules.contains(requiredModule)) {
        codes.add(ProductNavigationValidationCode.compositionModuleNotCompiled);
      }
      if (!_allowedRenderTiers(
        profile.profileId,
      ).contains(section.renderTier)) {
        codes.add(ProductNavigationValidationCode.renderTierUnsupported);
      }
    }

    return codes.isEmpty
        ? const [ProductNavigationValidationCode.accepted]
        : codes.toSet().toList(growable: false);
  }

  Set<ProductNavigationRenderTier> _allowedRenderTiers(
    ProductProfileId profileId,
  ) {
    return switch (profileId) {
      ProductProfileId.fullTv => const {
        ProductNavigationRenderTier.rich,
        ProductNavigationRenderTier.standard,
        ProductNavigationRenderTier.lightweight,
      },
      ProductProfileId.standardTv => const {
        ProductNavigationRenderTier.standard,
        ProductNavigationRenderTier.lightweight,
      },
      ProductProfileId.liteReceiver ||
      ProductProfileId.embeddedReceiver ||
      ProductProfileId.experimentalLegacy => const {
        ProductNavigationRenderTier.lightweight,
      },
    };
  }

  @override
  List<Object?> get props => const [];
}

class AiroTvProductProfiles {
  const AiroTvProductProfiles._();

  static ProductProfileManifest fullTv() {
    return ProductProfileManifest(
      profileId: ProductProfileId.fullTv,
      displayName: 'Airo TV',
      supportLevel: ProductSupportLevel.certified,
      releaseChannel: ProductReleaseChannel.fullTvStable,
      includedModules: const {
        ProductModule.playback,
        ProductModule.playlistImport,
        ProductModule.favorites,
        ProductModule.recent,
        ProductModule.basicSearch,
        ProductModule.compactEpg,
        ProductModule.fullEpg,
        ProductModule.pairing,
        ProductModule.remoteControl,
        ProductModule.diagnostics,
        ProductModule.analytics,
      },
      excludedModules: const {
        ProductModule.recording,
        ProductModule.downloads,
        ProductModule.multiview,
      },
      capabilities: const {
        ProductCapability.directPlayback,
        ProductCapability.dpadNavigation,
        ProductCapability.companionRemote,
        ProductCapability.compactEpg,
        ProductCapability.fullEpg,
        ProductCapability.basicSearch,
        ProductCapability.diagnostics,
        ProductCapability.analytics,
      },
      navigation: const [
        ProductNavigationEntry.home,
        ProductNavigationEntry.live,
        ProductNavigationEntry.guide,
        ProductNavigationEntry.favorites,
        ProductNavigationEntry.recent,
        ProductNavigationEntry.search,
        ProductNavigationEntry.settings,
        ProductNavigationEntry.diagnostics,
      ],
      androidPermissions: const {
        'android.permission.INTERNET',
        'android.permission.ACCESS_NETWORK_STATE',
      },
      guarantees: const {
        ProductProfileGuarantee.byocOnly,
        ProductProfileGuarantee.directPlayback,
        ProductProfileGuarantee.dpadNavigation,
        ProductProfileGuarantee.companionRemote,
        ProductProfileGuarantee.noBundledContent,
        ProductProfileGuarantee.permissionMinimized,
        ProductProfileGuarantee.profileScopedNavigation,
      },
      resourceBudget: const ProductResourceBudget(
        maxMemoryMb: 1024,
        maxStorageMb: 512,
        maxArtworkCacheMb: 96,
        maxBackgroundJobs: 4,
      ),
      deviceRequirement: DeviceCapabilityRequirement(
        minApiLevel: 26,
        minMemoryMb: 2048,
        minFreeStorageMb: 512,
        minDecoderCount: 1,
        requiredCodecs: const {
          MediaCodecCapability.h264,
          MediaCodecCapability.aac,
          MediaCodecCapability.hls,
        },
      ),
    );
  }

  static ProductProfileManifest liteReceiver() {
    return ProductProfileManifest(
      profileId: ProductProfileId.liteReceiver,
      displayName: 'Airo TV Lite Receiver',
      supportLevel: ProductSupportLevel.compatible,
      releaseChannel: ProductReleaseChannel.liteReceiverStable,
      includedModules: const {
        ProductModule.playback,
        ProductModule.favorites,
        ProductModule.recent,
        ProductModule.basicSearch,
        ProductModule.compactEpg,
        ProductModule.pairing,
        ProductModule.remoteControl,
        ProductModule.diagnostics,
      },
      excludedModules: const {
        ProductModule.fullEpg,
        ProductModule.localAi,
        ProductModule.recording,
        ProductModule.downloads,
        ProductModule.multiview,
      },
      capabilities: const {
        ProductCapability.directPlayback,
        ProductCapability.dpadNavigation,
        ProductCapability.companionRemote,
        ProductCapability.compactEpg,
        ProductCapability.basicSearch,
        ProductCapability.diagnostics,
      },
      navigation: const [
        ProductNavigationEntry.home,
        ProductNavigationEntry.live,
        ProductNavigationEntry.favorites,
        ProductNavigationEntry.recent,
        ProductNavigationEntry.search,
        ProductNavigationEntry.settings,
        ProductNavigationEntry.diagnostics,
      ],
      androidPermissions: const {
        'android.permission.INTERNET',
        'android.permission.ACCESS_NETWORK_STATE',
      },
      guarantees: const {
        ProductProfileGuarantee.byocOnly,
        ProductProfileGuarantee.directPlayback,
        ProductProfileGuarantee.dpadNavigation,
        ProductProfileGuarantee.companionRemote,
        ProductProfileGuarantee.compactData,
        ProductProfileGuarantee.noBundledContent,
        ProductProfileGuarantee.permissionMinimized,
        ProductProfileGuarantee.restrictedTrustCompatible,
        ProductProfileGuarantee.profileScopedNavigation,
      },
      resourceBudget: const ProductResourceBudget(
        maxMemoryMb: 384,
        maxStorageMb: 128,
        maxArtworkCacheMb: 16,
        maxBackgroundJobs: 1,
      ),
      deviceRequirement: DeviceCapabilityRequirement(
        minApiLevel: 26,
        minMemoryMb: 1024,
        minFreeStorageMb: 128,
        minDecoderCount: 1,
        requiredCodecs: const {
          MediaCodecCapability.h264,
          MediaCodecCapability.aac,
          MediaCodecCapability.hls,
        },
      ),
    );
  }
}

class AiroTvNavigationManifests {
  const AiroTvNavigationManifests._();

  static ProductNavigationManifest fullTv() {
    return ProductNavigationManifest(
      profileId: ProductProfileId.fullTv,
      sections: const [
        ProductNavigationSection(
          entry: ProductNavigationEntry.home,
          routeId: 'tv.home',
          displayKey: 'navigation.home',
          renderTier: ProductNavigationRenderTier.rich,
        ),
        ProductNavigationSection(
          entry: ProductNavigationEntry.live,
          routeId: 'tv.live',
          displayKey: 'navigation.live',
          renderTier: ProductNavigationRenderTier.rich,
          requiredModule: ProductModule.playback,
          requiredCapability: ProductCapability.directPlayback,
        ),
        ProductNavigationSection(
          entry: ProductNavigationEntry.guide,
          routeId: 'tv.guide',
          displayKey: 'navigation.guide',
          renderTier: ProductNavigationRenderTier.standard,
          requiredModule: ProductModule.fullEpg,
          requiredCapability: ProductCapability.fullEpg,
        ),
        ProductNavigationSection(
          entry: ProductNavigationEntry.favorites,
          routeId: 'tv.favorites',
          displayKey: 'navigation.favorites',
          renderTier: ProductNavigationRenderTier.standard,
          requiredModule: ProductModule.favorites,
        ),
        ProductNavigationSection(
          entry: ProductNavigationEntry.recent,
          routeId: 'tv.recent',
          displayKey: 'navigation.recent',
          renderTier: ProductNavigationRenderTier.standard,
          requiredModule: ProductModule.recent,
        ),
        ProductNavigationSection(
          entry: ProductNavigationEntry.search,
          routeId: 'tv.search',
          displayKey: 'navigation.search',
          renderTier: ProductNavigationRenderTier.standard,
          requiredModule: ProductModule.basicSearch,
          requiredCapability: ProductCapability.basicSearch,
        ),
        ProductNavigationSection(
          entry: ProductNavigationEntry.settings,
          routeId: 'tv.settings',
          displayKey: 'navigation.settings',
          renderTier: ProductNavigationRenderTier.standard,
        ),
        ProductNavigationSection(
          entry: ProductNavigationEntry.diagnostics,
          routeId: 'tv.diagnostics',
          displayKey: 'navigation.diagnostics',
          renderTier: ProductNavigationRenderTier.lightweight,
          requiredModule: ProductModule.diagnostics,
          requiredCapability: ProductCapability.diagnostics,
        ),
      ],
    );
  }

  static ProductNavigationManifest liteReceiver() {
    return ProductNavigationManifest(
      profileId: ProductProfileId.liteReceiver,
      sections: const [
        ProductNavigationSection(
          entry: ProductNavigationEntry.home,
          routeId: 'lite.home',
          displayKey: 'navigation.home',
          renderTier: ProductNavigationRenderTier.lightweight,
        ),
        ProductNavigationSection(
          entry: ProductNavigationEntry.live,
          routeId: 'lite.live',
          displayKey: 'navigation.live',
          renderTier: ProductNavigationRenderTier.lightweight,
          requiredModule: ProductModule.playback,
          requiredCapability: ProductCapability.directPlayback,
        ),
        ProductNavigationSection(
          entry: ProductNavigationEntry.favorites,
          routeId: 'lite.favorites',
          displayKey: 'navigation.favorites',
          renderTier: ProductNavigationRenderTier.lightweight,
          requiredModule: ProductModule.favorites,
        ),
        ProductNavigationSection(
          entry: ProductNavigationEntry.recent,
          routeId: 'lite.recent',
          displayKey: 'navigation.recent',
          renderTier: ProductNavigationRenderTier.lightweight,
          requiredModule: ProductModule.recent,
        ),
        ProductNavigationSection(
          entry: ProductNavigationEntry.search,
          routeId: 'lite.search',
          displayKey: 'navigation.search',
          renderTier: ProductNavigationRenderTier.lightweight,
          requiredModule: ProductModule.basicSearch,
          requiredCapability: ProductCapability.basicSearch,
        ),
        ProductNavigationSection(
          entry: ProductNavigationEntry.settings,
          routeId: 'lite.settings',
          displayKey: 'navigation.settings',
          renderTier: ProductNavigationRenderTier.lightweight,
        ),
        ProductNavigationSection(
          entry: ProductNavigationEntry.diagnostics,
          routeId: 'lite.diagnostics',
          displayKey: 'navigation.diagnostics',
          renderTier: ProductNavigationRenderTier.lightweight,
          requiredModule: ProductModule.diagnostics,
          requiredCapability: ProductCapability.diagnostics,
        ),
      ],
    );
  }

  static ProductNavigationManifest embeddedReceiver() {
    return ProductNavigationManifest(
      profileId: ProductProfileId.embeddedReceiver,
      sections: const [
        ProductNavigationSection(
          entry: ProductNavigationEntry.home,
          routeId: 'embedded.home',
          displayKey: 'navigation.home',
          renderTier: ProductNavigationRenderTier.lightweight,
        ),
        ProductNavigationSection(
          entry: ProductNavigationEntry.live,
          routeId: 'embedded.live',
          displayKey: 'navigation.live',
          renderTier: ProductNavigationRenderTier.lightweight,
          requiredModule: ProductModule.playback,
          requiredCapability: ProductCapability.directPlayback,
        ),
        ProductNavigationSection(
          entry: ProductNavigationEntry.settings,
          routeId: 'embedded.settings',
          displayKey: 'navigation.settings',
          renderTier: ProductNavigationRenderTier.lightweight,
        ),
      ],
    );
  }
}

class AiroTvModuleLifecycleManifests {
  const AiroTvModuleLifecycleManifests._();

  static List<ProductModuleLifecycleManifest> fullTv() {
    return [
      playback(),
      playlistImport(),
      favorites(),
      recent(),
      basicSearch(),
      compactEpg(),
      fullEpg(),
      pairing(),
      remoteControl(),
      diagnostics(),
      analytics(),
    ];
  }

  static List<ProductModuleLifecycleManifest> liteReceiver() {
    return [
      playback(),
      favorites(),
      recent(),
      basicSearch(),
      compactEpg(),
      pairing(),
      remoteControl(),
      diagnostics(),
    ];
  }

  static ProductModuleLifecycleManifest playback() {
    return ProductModuleLifecycleManifest(
      module: ProductModule.playback,
      displayName: 'Playback',
      supportedProfiles: const {
        ProductProfileId.fullTv,
        ProductProfileId.standardTv,
        ProductProfileId.liteReceiver,
        ProductProfileId.embeddedReceiver,
      },
      dependencies: const {},
      requiredCapabilities: const {ProductCapability.directPlayback},
      androidPermissions: const {
        'android.permission.INTERNET',
        'android.permission.ACCESS_NETWORK_STATE',
      },
      budget: const ProductModuleLifecycleBudget(
        initializationCostMs: 500,
        maxMemoryMb: 96,
        maxStorageMb: 0,
        maxBackgroundJobs: 0,
      ),
    );
  }

  static ProductModuleLifecycleManifest playlistImport() {
    return _lightweightModule(
      module: ProductModule.playlistImport,
      displayName: 'Playlist Import',
      supportedProfiles: const {
        ProductProfileId.fullTv,
        ProductProfileId.standardTv,
      },
      maxStorageMb: 8,
    );
  }

  static ProductModuleLifecycleManifest favorites() {
    return _lightweightModule(
      module: ProductModule.favorites,
      displayName: 'Favorites',
      maxStorageMb: 4,
    );
  }

  static ProductModuleLifecycleManifest recent() {
    return _lightweightModule(
      module: ProductModule.recent,
      displayName: 'Recent',
      maxStorageMb: 4,
    );
  }

  static ProductModuleLifecycleManifest basicSearch() {
    return _lightweightModule(
      module: ProductModule.basicSearch,
      displayName: 'Basic Search',
      requiredCapabilities: const {ProductCapability.basicSearch},
      maxMemoryMb: 48,
      maxStorageMb: 12,
    );
  }

  static ProductModuleLifecycleManifest compactEpg() {
    return ProductModuleLifecycleManifest(
      module: ProductModule.compactEpg,
      displayName: 'Compact EPG',
      supportedProfiles: const {
        ProductProfileId.fullTv,
        ProductProfileId.standardTv,
        ProductProfileId.liteReceiver,
        ProductProfileId.embeddedReceiver,
      },
      dependencies: const {ProductModule.playback},
      requiredCapabilities: const {ProductCapability.compactEpg},
      androidPermissions: const {'android.permission.INTERNET'},
      budget: const ProductModuleLifecycleBudget(
        initializationCostMs: 700,
        maxMemoryMb: 64,
        maxStorageMb: 24,
        maxBackgroundJobs: 1,
      ),
      backgroundTasks: const {ProductModuleBackgroundTask.epgRefresh},
      allowsBackgroundExecution: true,
      supportsGracefulShutdown: true,
    );
  }

  static ProductModuleLifecycleManifest fullEpg() {
    return ProductModuleLifecycleManifest(
      module: ProductModule.fullEpg,
      displayName: 'Full EPG',
      supportedProfiles: const {
        ProductProfileId.fullTv,
        ProductProfileId.standardTv,
      },
      dependencies: const {ProductModule.playback, ProductModule.compactEpg},
      requiredCapabilities: const {
        ProductCapability.compactEpg,
        ProductCapability.fullEpg,
      },
      androidPermissions: const {'android.permission.INTERNET'},
      budget: const ProductModuleLifecycleBudget(
        initializationCostMs: 1200,
        maxMemoryMb: 192,
        maxStorageMb: 128,
        maxBackgroundJobs: 1,
      ),
      backgroundTasks: const {ProductModuleBackgroundTask.epgRefresh},
      featureFlags: const {ProductModuleFeatureFlag.fullEpg},
      fallbackModule: ProductModule.compactEpg,
      allowsBackgroundExecution: true,
      supportsGracefulShutdown: true,
    );
  }

  static ProductModuleLifecycleManifest pairing() {
    return _lightweightModule(
      module: ProductModule.pairing,
      displayName: 'Pairing',
      maxMemoryMb: 32,
      maxStorageMb: 4,
    );
  }

  static ProductModuleLifecycleManifest remoteControl() {
    return _lightweightModule(
      module: ProductModule.remoteControl,
      displayName: 'Remote Control',
      requiredCapabilities: const {ProductCapability.companionRemote},
      maxMemoryMb: 32,
      maxStorageMb: 4,
    );
  }

  static ProductModuleLifecycleManifest diagnostics() {
    return _lightweightModule(
      module: ProductModule.diagnostics,
      displayName: 'Diagnostics',
      requiredCapabilities: const {ProductCapability.diagnostics},
      featureFlags: const {ProductModuleFeatureFlag.diagnostics},
      maxMemoryMb: 32,
      maxStorageMb: 8,
    );
  }

  static ProductModuleLifecycleManifest analytics() {
    return ProductModuleLifecycleManifest(
      module: ProductModule.analytics,
      displayName: 'Analytics',
      supportedProfiles: const {
        ProductProfileId.fullTv,
        ProductProfileId.standardTv,
      },
      dependencies: const {},
      requiredCapabilities: const {ProductCapability.analytics},
      androidPermissions: const {'android.permission.ACCESS_NETWORK_STATE'},
      budget: const ProductModuleLifecycleBudget(
        initializationCostMs: 400,
        maxMemoryMb: 32,
        maxStorageMb: 8,
        maxBackgroundJobs: 1,
      ),
      backgroundTasks: const {ProductModuleBackgroundTask.analyticsFlush},
      featureFlags: const {ProductModuleFeatureFlag.analytics},
      allowsBackgroundExecution: true,
      supportsGracefulShutdown: true,
    );
  }

  static ProductModuleLifecycleManifest localAi() {
    return ProductModuleLifecycleManifest(
      module: ProductModule.localAi,
      displayName: 'Local AI',
      supportedProfiles: const {ProductProfileId.fullTv},
      dependencies: const {ProductModule.basicSearch},
      requiredCapabilities: const {ProductCapability.localAi},
      androidPermissions: const {},
      budget: const ProductModuleLifecycleBudget(
        initializationCostMs: 2500,
        maxMemoryMb: 512,
        maxStorageMb: 128,
        maxBackgroundJobs: 2,
      ),
      backgroundTasks: const {ProductModuleBackgroundTask.modelWarmup},
      featureFlags: const {ProductModuleFeatureFlag.localAi},
      fallbackModule: ProductModule.basicSearch,
      allowsBackgroundExecution: true,
      supportsGracefulShutdown: true,
    );
  }

  static ProductModuleLifecycleManifest _lightweightModule({
    required ProductModule module,
    required String displayName,
    Set<ProductProfileId> supportedProfiles = const {
      ProductProfileId.fullTv,
      ProductProfileId.standardTv,
      ProductProfileId.liteReceiver,
      ProductProfileId.embeddedReceiver,
    },
    Set<ProductCapability> requiredCapabilities = const {},
    Set<ProductModuleFeatureFlag> featureFlags = const {},
    int maxMemoryMb = 24,
    int maxStorageMb = 0,
  }) {
    return ProductModuleLifecycleManifest(
      module: module,
      displayName: displayName,
      supportedProfiles: supportedProfiles,
      dependencies: const {},
      requiredCapabilities: requiredCapabilities,
      androidPermissions: const {},
      budget: ProductModuleLifecycleBudget(
        initializationCostMs: 250,
        maxMemoryMb: maxMemoryMb,
        maxStorageMb: maxStorageMb,
        maxBackgroundJobs: 0,
      ),
      featureFlags: featureFlags,
    );
  }
}

class AiroTvProductCompositions {
  const AiroTvProductCompositions._();

  static ProductCompositionManifest fullTv() {
    final profile = AiroTvProductProfiles.fullTv();
    return ProductCompositionManifest(
      profileManifest: profile,
      compiledModules: profile.includedModules,
      lifecycleManifests: AiroTvModuleLifecycleManifests.fullTv(),
      enabledFeatureFlags: const {
        ProductModuleFeatureFlag.fullEpg,
        ProductModuleFeatureFlag.diagnostics,
        ProductModuleFeatureFlag.analytics,
      },
    );
  }

  static ProductCompositionManifest liteReceiver() {
    final profile = AiroTvProductProfiles.liteReceiver();
    return ProductCompositionManifest(
      profileManifest: profile,
      compiledModules: profile.includedModules,
      lifecycleManifests: AiroTvModuleLifecycleManifests.liteReceiver(),
      enabledFeatureFlags: const {ProductModuleFeatureFlag.diagnostics},
    );
  }
}

class AiroTvCapabilityAdvertisements {
  const AiroTvCapabilityAdvertisements._();

  static ProductCapabilityAdvertisement fullTv(
    DeviceCapabilitySnapshot deviceSnapshot,
  ) {
    return const ProductCapabilityAdvertisementPolicy().publish(
      composition: AiroTvProductCompositions.fullTv(),
      deviceSnapshot: deviceSnapshot,
    );
  }

  static ProductCapabilityAdvertisement liteReceiver(
    DeviceCapabilitySnapshot deviceSnapshot,
  ) {
    return const ProductCapabilityAdvertisementPolicy().publish(
      composition: AiroTvProductCompositions.liteReceiver(),
      deviceSnapshot: deviceSnapshot,
    );
  }
}

ProductModule? _moduleForCapability(ProductCapability capability) {
  return switch (capability) {
    ProductCapability.directPlayback => ProductModule.playback,
    ProductCapability.dpadNavigation => null,
    ProductCapability.companionRemote => ProductModule.remoteControl,
    ProductCapability.compactEpg => ProductModule.compactEpg,
    ProductCapability.fullEpg => ProductModule.fullEpg,
    ProductCapability.basicSearch => ProductModule.basicSearch,
    ProductCapability.diagnostics => ProductModule.diagnostics,
    ProductCapability.analytics => ProductModule.analytics,
    ProductCapability.localAi => ProductModule.localAi,
    ProductCapability.recording => ProductModule.recording,
    ProductCapability.downloads => ProductModule.downloads,
    ProductCapability.multiview => ProductModule.multiview,
  };
}

List<String> _productProfileStableIds(Iterable<ProductProfileId> values) {
  return values.map((value) => value.stableId).toList(growable: false)..sort();
}

List<String> _productModuleStableIds(Iterable<ProductModule> values) {
  return values.map((value) => value.stableId).toList(growable: false)..sort();
}

List<String> _productCapabilityStableIds(Iterable<ProductCapability> values) {
  return values.map((value) => value.stableId).toList(growable: false)..sort();
}

List<String> _productGuaranteeStableIds(
  Iterable<ProductProfileGuarantee> values,
) {
  return values.map((value) => value.stableId).toList(growable: false)..sort();
}

List<String> _mediaCodecStableIds(Iterable<MediaCodecCapability> values) {
  return values.map((value) => value.stableId).toList(growable: false)..sort();
}

List<String> _manifestValidationCodeStableIds(
  Iterable<ProductManifestValidationCode> values,
) {
  return values.map((value) => value.stableId).toList(growable: false)..sort();
}

List<String> _moduleLifecycleValidationCodeStableIds(
  Iterable<ProductModuleLifecycleValidationCode> values,
) {
  return values.map((value) => value.stableId).toList(growable: false)..sort();
}

List<String> _moduleBackgroundTaskStableIds(
  Iterable<ProductModuleBackgroundTask> values,
) {
  return values.map((value) => value.stableId).toList(growable: false)..sort();
}

List<String> _moduleFeatureFlagStableIds(
  Iterable<ProductModuleFeatureFlag> values,
) {
  return values.map((value) => value.stableId).toList(growable: false)..sort();
}

List<String> _compositionValidationCodeStableIds(
  Iterable<ProductCompositionValidationCode> values,
) {
  return values.map((value) => value.stableId).toList(growable: false)..sort();
}
