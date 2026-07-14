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
