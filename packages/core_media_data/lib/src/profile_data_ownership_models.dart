import 'package:equatable/equatable.dart';

const String kAiroProfileDataOwnershipSchemaVersion = '1.0.0';

enum AiroDataProfile {
  fullTv('full_tv'),
  liteReceiver('lite_receiver'),
  embeddedReceiver('embedded_receiver'),
  mobileCompanion('mobile_companion'),
  desktopCompanion('desktop_companion'),
  homeNode('home_node');

  const AiroDataProfile(this.stableId);

  final String stableId;
}

enum AiroDataDomain {
  playlistIndex('playlist_index'),
  epg('epg'),
  favorites('favorites'),
  progress('progress'),
  aiEmbeddings('ai_embeddings'),
  streamHealth('stream_health'),
  artwork('artwork'),
  thumbnails('thumbnails'),
  credentialRefs('credential_refs');

  const AiroDataDomain(this.stableId);

  final String stableId;
}

enum AiroDataStorageScope {
  unsupported('unsupported'),
  localDevice('local_device'),
  profileScoped('profile_scoped'),
  encryptedVault('encrypted_vault'),
  delegatedReadOnly('delegated_read_only'),
  cloudPreserved('cloud_preserved');

  const AiroDataStorageScope(this.stableId);

  final String stableId;
}

enum AiroDataSyncMode {
  none('none'),
  localOnly('local_only'),
  optionalEncrypted('optional_encrypted'),
  delegatedReadOnly('delegated_read_only'),
  cloudPreserved('cloud_preserved');

  const AiroDataSyncMode(this.stableId);

  final String stableId;
}

enum AiroDataMigrationStrategy {
  retainLocal('retain_local'),
  rehydrateFromOwner('rehydrate_from_owner'),
  compactForReceiver('compact_for_receiver'),
  preserveHiddenCloud('preserve_hidden_cloud'),
  delegatedReadOnly('delegated_read_only'),
  clearCacheOnly('clear_cache_only'),
  unsupported('unsupported');

  const AiroDataMigrationStrategy(this.stableId);

  final String stableId;
}

enum AiroDataOwnershipValidationCode {
  accepted('accepted'),
  missingDomainRule('missing_domain_rule'),
  duplicateDomainRule('duplicate_domain_rule'),
  cacheBudgetInvalid('cache_budget_invalid'),
  credentialStorageUnsafe('credential_storage_unsafe'),
  unsupportedSyncMode('unsupported_sync_mode'),
  unsupportedDataNotPreserved('unsupported_data_not_preserved'),
  liteOwnsHeavyData('lite_owns_heavy_data'),
  embeddedOwnsHeavyData('embedded_owns_heavy_data'),
  upgradeStrategyMissing('upgrade_strategy_missing'),
  downgradeStrategyUnsafe('downgrade_strategy_unsafe'),
  unsafeOwnerProfile('unsafe_owner_profile');

  const AiroDataOwnershipValidationCode(this.stableId);

  final String stableId;
}

class AiroProfileDataOwnershipRule extends Equatable {
  const AiroProfileDataOwnershipRule({
    required this.domain,
    required this.ownerProfile,
    required this.storageScope,
    required this.syncMode,
    required this.upgradeStrategy,
    required this.downgradeStrategy,
    required this.preserveWhenUnsupported,
    required this.encryptedAtRest,
    required this.maxCacheMb,
  });

  final AiroDataDomain domain;
  final AiroDataProfile ownerProfile;
  final AiroDataStorageScope storageScope;
  final AiroDataSyncMode syncMode;
  final AiroDataMigrationStrategy upgradeStrategy;
  final AiroDataMigrationStrategy downgradeStrategy;
  final bool preserveWhenUnsupported;
  final bool encryptedAtRest;
  final int maxCacheMb;

  bool get isUnsupported => storageScope == AiroDataStorageScope.unsupported;

  Map<String, Object?> toPublicMap() {
    return {
      'domain': domain.stableId,
      'ownerProfile': ownerProfile.stableId,
      'storageScope': storageScope.stableId,
      'syncMode': syncMode.stableId,
      'upgradeStrategy': upgradeStrategy.stableId,
      'downgradeStrategy': downgradeStrategy.stableId,
      'preserveWhenUnsupported': preserveWhenUnsupported,
      'encryptedAtRest': encryptedAtRest,
      'maxCacheMb': maxCacheMb,
    };
  }

  @override
  List<Object?> get props => [
    domain,
    ownerProfile,
    storageScope,
    syncMode,
    upgradeStrategy,
    downgradeStrategy,
    preserveWhenUnsupported,
    encryptedAtRest,
    maxCacheMb,
  ];
}

class AiroProfileDataOwnershipMatrix extends Equatable {
  AiroProfileDataOwnershipMatrix({
    required this.profile,
    required Iterable<AiroProfileDataOwnershipRule> rules,
    this.schemaVersion = kAiroProfileDataOwnershipSchemaVersion,
  }) : rules = List.unmodifiable(rules);

  final String schemaVersion;
  final AiroDataProfile profile;
  final List<AiroProfileDataOwnershipRule> rules;

  List<AiroDataOwnershipValidationCode> validate() {
    return const AiroProfileDataOwnershipPolicy().evaluate(this);
  }

  AiroProfileDataOwnershipRule? ruleFor(AiroDataDomain domain) {
    for (final rule in rules) {
      if (rule.domain == domain) return rule;
    }
    return null;
  }

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'profile': profile.stableId,
      'rules': rules.map((rule) => rule.toPublicMap()).toList(growable: false),
    };
  }

  @override
  List<Object?> get props => [schemaVersion, profile, rules];
}

class AiroProfileDataOwnershipPolicy extends Equatable {
  const AiroProfileDataOwnershipPolicy();

  List<AiroDataOwnershipValidationCode> evaluate(
    AiroProfileDataOwnershipMatrix matrix,
  ) {
    final codes = <AiroDataOwnershipValidationCode>[];
    final seenDomains = <AiroDataDomain>{};

    for (final domain in AiroDataDomain.values) {
      if (matrix.ruleFor(domain) == null) {
        codes.add(AiroDataOwnershipValidationCode.missingDomainRule);
      }
    }

    for (final rule in matrix.rules) {
      if (!seenDomains.add(rule.domain)) {
        codes.add(AiroDataOwnershipValidationCode.duplicateDomainRule);
      }
      if (rule.maxCacheMb < 0) {
        codes.add(AiroDataOwnershipValidationCode.cacheBudgetInvalid);
      }
      if (rule.domain == AiroDataDomain.credentialRefs &&
          (!rule.encryptedAtRest ||
              rule.storageScope != AiroDataStorageScope.encryptedVault)) {
        codes.add(AiroDataOwnershipValidationCode.credentialStorageUnsafe);
      }
      if (rule.storageScope == AiroDataStorageScope.unsupported &&
          rule.syncMode != AiroDataSyncMode.none &&
          rule.syncMode != AiroDataSyncMode.cloudPreserved) {
        codes.add(AiroDataOwnershipValidationCode.unsupportedSyncMode);
      }
      if (rule.storageScope == AiroDataStorageScope.unsupported &&
          !rule.preserveWhenUnsupported) {
        codes.add(AiroDataOwnershipValidationCode.unsupportedDataNotPreserved);
      }
      if (_isLiteOrEmbedded(matrix.profile) &&
          _isHeavyDomain(rule.domain) &&
          _isLocalOwnership(rule)) {
        codes.add(
          matrix.profile == AiroDataProfile.liteReceiver
              ? AiroDataOwnershipValidationCode.liteOwnsHeavyData
              : AiroDataOwnershipValidationCode.embeddedOwnsHeavyData,
        );
      }
      if (_requiresUpgradeStrategy(rule) &&
          rule.upgradeStrategy == AiroDataMigrationStrategy.unsupported) {
        codes.add(AiroDataOwnershipValidationCode.upgradeStrategyMissing);
      }
      if (_requiresDowngradePreservation(rule.domain) &&
          rule.downgradeStrategy !=
              AiroDataMigrationStrategy.preserveHiddenCloud &&
          rule.downgradeStrategy !=
              AiroDataMigrationStrategy.compactForReceiver &&
          rule.downgradeStrategy !=
              AiroDataMigrationStrategy.delegatedReadOnly &&
          !(_isRehydratableCacheDomain(rule.domain) &&
              rule.downgradeStrategy ==
                  AiroDataMigrationStrategy.clearCacheOnly)) {
        codes.add(AiroDataOwnershipValidationCode.downgradeStrategyUnsafe);
      }
      if (rule.storageScope == AiroDataStorageScope.cloudPreserved &&
          rule.ownerProfile == matrix.profile) {
        codes.add(AiroDataOwnershipValidationCode.unsafeOwnerProfile);
      }
    }

    return codes.isEmpty
        ? const [AiroDataOwnershipValidationCode.accepted]
        : codes.toSet().toList(growable: false);
  }

  bool _isLiteOrEmbedded(AiroDataProfile profile) {
    return profile == AiroDataProfile.liteReceiver ||
        profile == AiroDataProfile.embeddedReceiver;
  }

  bool _isHeavyDomain(AiroDataDomain domain) {
    return domain == AiroDataDomain.epg ||
        domain == AiroDataDomain.aiEmbeddings ||
        domain == AiroDataDomain.streamHealth ||
        domain == AiroDataDomain.artwork ||
        domain == AiroDataDomain.thumbnails;
  }

  bool _isLocalOwnership(AiroProfileDataOwnershipRule rule) {
    return rule.storageScope == AiroDataStorageScope.localDevice ||
        rule.storageScope == AiroDataStorageScope.profileScoped ||
        rule.ownerProfile == AiroDataProfile.liteReceiver ||
        rule.ownerProfile == AiroDataProfile.embeddedReceiver;
  }

  bool _requiresUpgradeStrategy(AiroProfileDataOwnershipRule rule) {
    return rule.storageScope == AiroDataStorageScope.delegatedReadOnly ||
        rule.storageScope == AiroDataStorageScope.cloudPreserved;
  }

  bool _requiresDowngradePreservation(AiroDataDomain domain) {
    return domain == AiroDataDomain.epg ||
        domain == AiroDataDomain.aiEmbeddings ||
        domain == AiroDataDomain.streamHealth ||
        domain == AiroDataDomain.artwork ||
        domain == AiroDataDomain.thumbnails ||
        domain == AiroDataDomain.credentialRefs;
  }

  bool _isRehydratableCacheDomain(AiroDataDomain domain) {
    return domain == AiroDataDomain.artwork ||
        domain == AiroDataDomain.thumbnails;
  }

  @override
  List<Object?> get props => const [];
}

class AiroTvProfileDataOwnershipMatrices {
  const AiroTvProfileDataOwnershipMatrices._();

  static AiroProfileDataOwnershipMatrix fullTv() {
    return AiroProfileDataOwnershipMatrix(
      profile: AiroDataProfile.fullTv,
      rules: const [
        AiroProfileDataOwnershipRule(
          domain: AiroDataDomain.playlistIndex,
          ownerProfile: AiroDataProfile.fullTv,
          storageScope: AiroDataStorageScope.profileScoped,
          syncMode: AiroDataSyncMode.optionalEncrypted,
          upgradeStrategy: AiroDataMigrationStrategy.retainLocal,
          downgradeStrategy: AiroDataMigrationStrategy.compactForReceiver,
          preserveWhenUnsupported: true,
          encryptedAtRest: true,
          maxCacheMb: 128,
        ),
        AiroProfileDataOwnershipRule(
          domain: AiroDataDomain.epg,
          ownerProfile: AiroDataProfile.fullTv,
          storageScope: AiroDataStorageScope.profileScoped,
          syncMode: AiroDataSyncMode.optionalEncrypted,
          upgradeStrategy: AiroDataMigrationStrategy.retainLocal,
          downgradeStrategy: AiroDataMigrationStrategy.compactForReceiver,
          preserveWhenUnsupported: true,
          encryptedAtRest: false,
          maxCacheMb: 256,
        ),
        AiroProfileDataOwnershipRule(
          domain: AiroDataDomain.favorites,
          ownerProfile: AiroDataProfile.fullTv,
          storageScope: AiroDataStorageScope.profileScoped,
          syncMode: AiroDataSyncMode.optionalEncrypted,
          upgradeStrategy: AiroDataMigrationStrategy.retainLocal,
          downgradeStrategy: AiroDataMigrationStrategy.retainLocal,
          preserveWhenUnsupported: true,
          encryptedAtRest: true,
          maxCacheMb: 8,
        ),
        AiroProfileDataOwnershipRule(
          domain: AiroDataDomain.progress,
          ownerProfile: AiroDataProfile.fullTv,
          storageScope: AiroDataStorageScope.profileScoped,
          syncMode: AiroDataSyncMode.optionalEncrypted,
          upgradeStrategy: AiroDataMigrationStrategy.retainLocal,
          downgradeStrategy: AiroDataMigrationStrategy.retainLocal,
          preserveWhenUnsupported: true,
          encryptedAtRest: true,
          maxCacheMb: 8,
        ),
        AiroProfileDataOwnershipRule(
          domain: AiroDataDomain.aiEmbeddings,
          ownerProfile: AiroDataProfile.fullTv,
          storageScope: AiroDataStorageScope.localDevice,
          syncMode: AiroDataSyncMode.localOnly,
          upgradeStrategy: AiroDataMigrationStrategy.rehydrateFromOwner,
          downgradeStrategy: AiroDataMigrationStrategy.preserveHiddenCloud,
          preserveWhenUnsupported: true,
          encryptedAtRest: true,
          maxCacheMb: 512,
        ),
        AiroProfileDataOwnershipRule(
          domain: AiroDataDomain.streamHealth,
          ownerProfile: AiroDataProfile.fullTv,
          storageScope: AiroDataStorageScope.profileScoped,
          syncMode: AiroDataSyncMode.optionalEncrypted,
          upgradeStrategy: AiroDataMigrationStrategy.rehydrateFromOwner,
          downgradeStrategy: AiroDataMigrationStrategy.compactForReceiver,
          preserveWhenUnsupported: true,
          encryptedAtRest: false,
          maxCacheMb: 64,
        ),
        AiroProfileDataOwnershipRule(
          domain: AiroDataDomain.artwork,
          ownerProfile: AiroDataProfile.fullTv,
          storageScope: AiroDataStorageScope.localDevice,
          syncMode: AiroDataSyncMode.localOnly,
          upgradeStrategy: AiroDataMigrationStrategy.rehydrateFromOwner,
          downgradeStrategy: AiroDataMigrationStrategy.clearCacheOnly,
          preserveWhenUnsupported: true,
          encryptedAtRest: false,
          maxCacheMb: 96,
        ),
        AiroProfileDataOwnershipRule(
          domain: AiroDataDomain.thumbnails,
          ownerProfile: AiroDataProfile.fullTv,
          storageScope: AiroDataStorageScope.localDevice,
          syncMode: AiroDataSyncMode.localOnly,
          upgradeStrategy: AiroDataMigrationStrategy.rehydrateFromOwner,
          downgradeStrategy: AiroDataMigrationStrategy.clearCacheOnly,
          preserveWhenUnsupported: true,
          encryptedAtRest: false,
          maxCacheMb: 64,
        ),
        AiroProfileDataOwnershipRule(
          domain: AiroDataDomain.credentialRefs,
          ownerProfile: AiroDataProfile.fullTv,
          storageScope: AiroDataStorageScope.encryptedVault,
          syncMode: AiroDataSyncMode.none,
          upgradeStrategy: AiroDataMigrationStrategy.retainLocal,
          downgradeStrategy: AiroDataMigrationStrategy.preserveHiddenCloud,
          preserveWhenUnsupported: true,
          encryptedAtRest: true,
          maxCacheMb: 1,
        ),
      ],
    );
  }

  static AiroProfileDataOwnershipMatrix liteReceiver() {
    return AiroProfileDataOwnershipMatrix(
      profile: AiroDataProfile.liteReceiver,
      rules: _receiverRules(AiroDataProfile.liteReceiver, playlistCacheMb: 24),
    );
  }

  static AiroProfileDataOwnershipMatrix embeddedReceiver() {
    return AiroProfileDataOwnershipMatrix(
      profile: AiroDataProfile.embeddedReceiver,
      rules: _receiverRules(
        AiroDataProfile.embeddedReceiver,
        playlistCacheMb: 8,
      ),
    );
  }

  static List<AiroProfileDataOwnershipRule> _receiverRules(
    AiroDataProfile profile, {
    required int playlistCacheMb,
  }) {
    return [
      AiroProfileDataOwnershipRule(
        domain: AiroDataDomain.playlistIndex,
        ownerProfile: profile,
        storageScope: AiroDataStorageScope.profileScoped,
        syncMode: AiroDataSyncMode.optionalEncrypted,
        upgradeStrategy: AiroDataMigrationStrategy.rehydrateFromOwner,
        downgradeStrategy: AiroDataMigrationStrategy.compactForReceiver,
        preserveWhenUnsupported: true,
        encryptedAtRest: true,
        maxCacheMb: playlistCacheMb,
      ),
      AiroProfileDataOwnershipRule(
        domain: AiroDataDomain.epg,
        ownerProfile: AiroDataProfile.homeNode,
        storageScope: AiroDataStorageScope.delegatedReadOnly,
        syncMode: AiroDataSyncMode.delegatedReadOnly,
        upgradeStrategy: AiroDataMigrationStrategy.rehydrateFromOwner,
        downgradeStrategy: AiroDataMigrationStrategy.compactForReceiver,
        preserveWhenUnsupported: true,
        encryptedAtRest: false,
        maxCacheMb: profile == AiroDataProfile.liteReceiver ? 16 : 4,
      ),
      AiroProfileDataOwnershipRule(
        domain: AiroDataDomain.favorites,
        ownerProfile: profile,
        storageScope: AiroDataStorageScope.profileScoped,
        syncMode: AiroDataSyncMode.optionalEncrypted,
        upgradeStrategy: AiroDataMigrationStrategy.retainLocal,
        downgradeStrategy: AiroDataMigrationStrategy.retainLocal,
        preserveWhenUnsupported: true,
        encryptedAtRest: true,
        maxCacheMb: 4,
      ),
      AiroProfileDataOwnershipRule(
        domain: AiroDataDomain.progress,
        ownerProfile: profile,
        storageScope: AiroDataStorageScope.profileScoped,
        syncMode: AiroDataSyncMode.optionalEncrypted,
        upgradeStrategy: AiroDataMigrationStrategy.retainLocal,
        downgradeStrategy: AiroDataMigrationStrategy.retainLocal,
        preserveWhenUnsupported: true,
        encryptedAtRest: true,
        maxCacheMb: 4,
      ),
      const AiroProfileDataOwnershipRule(
        domain: AiroDataDomain.aiEmbeddings,
        ownerProfile: AiroDataProfile.homeNode,
        storageScope: AiroDataStorageScope.cloudPreserved,
        syncMode: AiroDataSyncMode.cloudPreserved,
        upgradeStrategy: AiroDataMigrationStrategy.rehydrateFromOwner,
        downgradeStrategy: AiroDataMigrationStrategy.preserveHiddenCloud,
        preserveWhenUnsupported: true,
        encryptedAtRest: true,
        maxCacheMb: 0,
      ),
      const AiroProfileDataOwnershipRule(
        domain: AiroDataDomain.streamHealth,
        ownerProfile: AiroDataProfile.homeNode,
        storageScope: AiroDataStorageScope.delegatedReadOnly,
        syncMode: AiroDataSyncMode.delegatedReadOnly,
        upgradeStrategy: AiroDataMigrationStrategy.rehydrateFromOwner,
        downgradeStrategy: AiroDataMigrationStrategy.compactForReceiver,
        preserveWhenUnsupported: true,
        encryptedAtRest: false,
        maxCacheMb: 4,
      ),
      const AiroProfileDataOwnershipRule(
        domain: AiroDataDomain.artwork,
        ownerProfile: AiroDataProfile.mobileCompanion,
        storageScope: AiroDataStorageScope.delegatedReadOnly,
        syncMode: AiroDataSyncMode.delegatedReadOnly,
        upgradeStrategy: AiroDataMigrationStrategy.rehydrateFromOwner,
        downgradeStrategy: AiroDataMigrationStrategy.clearCacheOnly,
        preserveWhenUnsupported: true,
        encryptedAtRest: false,
        maxCacheMb: 8,
      ),
      const AiroProfileDataOwnershipRule(
        domain: AiroDataDomain.thumbnails,
        ownerProfile: AiroDataProfile.mobileCompanion,
        storageScope: AiroDataStorageScope.delegatedReadOnly,
        syncMode: AiroDataSyncMode.delegatedReadOnly,
        upgradeStrategy: AiroDataMigrationStrategy.rehydrateFromOwner,
        downgradeStrategy: AiroDataMigrationStrategy.clearCacheOnly,
        preserveWhenUnsupported: true,
        encryptedAtRest: false,
        maxCacheMb: 8,
      ),
      const AiroProfileDataOwnershipRule(
        domain: AiroDataDomain.credentialRefs,
        ownerProfile: AiroDataProfile.mobileCompanion,
        storageScope: AiroDataStorageScope.encryptedVault,
        syncMode: AiroDataSyncMode.none,
        upgradeStrategy: AiroDataMigrationStrategy.rehydrateFromOwner,
        downgradeStrategy: AiroDataMigrationStrategy.preserveHiddenCloud,
        preserveWhenUnsupported: true,
        encryptedAtRest: true,
        maxCacheMb: 1,
      ),
    ];
  }
}
