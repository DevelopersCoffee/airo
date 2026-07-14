import 'package:core_media_data/core_media_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiroProfileDataOwnershipPolicy', () {
    test('full TV matrix owns complete profile data safely', () {
      final matrix = AiroTvProfileDataOwnershipMatrices.fullTv();

      expect(matrix.validate(), const [
        AiroDataOwnershipValidationCode.accepted,
      ]);
      expect(
        matrix.ruleFor(AiroDataDomain.credentialRefs)?.storageScope,
        AiroDataStorageScope.encryptedVault,
      );
      expect(
        matrix.ruleFor(AiroDataDomain.aiEmbeddings)?.syncMode,
        AiroDataSyncMode.localOnly,
      );
    });

    test(
      'lite receiver delegates heavy data and preserves unsupported state',
      () {
        final matrix = AiroTvProfileDataOwnershipMatrices.liteReceiver();

        expect(matrix.validate(), const [
          AiroDataOwnershipValidationCode.accepted,
        ]);
        expect(
          matrix.ruleFor(AiroDataDomain.epg)?.storageScope,
          AiroDataStorageScope.delegatedReadOnly,
        );
        expect(
          matrix.ruleFor(AiroDataDomain.aiEmbeddings)?.storageScope,
          AiroDataStorageScope.cloudPreserved,
        );
        expect(
          matrix.ruleFor(AiroDataDomain.streamHealth)?.ownerProfile,
          AiroDataProfile.homeNode,
        );
        expect(
          matrix.ruleFor(AiroDataDomain.credentialRefs)?.encryptedAtRest,
          isTrue,
        );
      },
    );

    test('embedded receiver keeps strict cache budgets', () {
      final matrix = AiroTvProfileDataOwnershipMatrices.embeddedReceiver();

      expect(matrix.validate(), const [
        AiroDataOwnershipValidationCode.accepted,
      ]);
      expect(matrix.ruleFor(AiroDataDomain.playlistIndex)?.maxCacheMb, 8);
      expect(matrix.ruleFor(AiroDataDomain.epg)?.maxCacheMb, 4);
      expect(
        matrix.ruleFor(AiroDataDomain.artwork)?.storageScope,
        AiroDataStorageScope.delegatedReadOnly,
      );
    });

    test('credential references must use encrypted vault storage', () {
      final matrix = _invalidMatrixWith(
        const AiroProfileDataOwnershipRule(
          domain: AiroDataDomain.credentialRefs,
          ownerProfile: AiroDataProfile.fullTv,
          storageScope: AiroDataStorageScope.profileScoped,
          syncMode: AiroDataSyncMode.optionalEncrypted,
          upgradeStrategy: AiroDataMigrationStrategy.retainLocal,
          downgradeStrategy: AiroDataMigrationStrategy.retainLocal,
          preserveWhenUnsupported: true,
          encryptedAtRest: false,
          maxCacheMb: 1,
        ),
      );

      expect(
        matrix.validate(),
        contains(AiroDataOwnershipValidationCode.credentialStorageUnsafe),
      );
    });

    test('lite receiver cannot locally own heavy datasets', () {
      final matrix = _liteMatrixWith(
        const AiroProfileDataOwnershipRule(
          domain: AiroDataDomain.aiEmbeddings,
          ownerProfile: AiroDataProfile.liteReceiver,
          storageScope: AiroDataStorageScope.localDevice,
          syncMode: AiroDataSyncMode.localOnly,
          upgradeStrategy: AiroDataMigrationStrategy.retainLocal,
          downgradeStrategy: AiroDataMigrationStrategy.clearCacheOnly,
          preserveWhenUnsupported: false,
          encryptedAtRest: false,
          maxCacheMb: 128,
        ),
      );

      final result = matrix.validate();

      expect(
        result,
        contains(AiroDataOwnershipValidationCode.liteOwnsHeavyData),
      );
      expect(
        result,
        contains(AiroDataOwnershipValidationCode.downgradeStrategyUnsafe),
      );
    });

    test('missing and duplicate domain rules are deterministic', () {
      final baseline = AiroTvProfileDataOwnershipMatrices.fullTv();
      final duplicate = baseline.ruleFor(AiroDataDomain.progress)!;
      final matrix = AiroProfileDataOwnershipMatrix(
        profile: AiroDataProfile.fullTv,
        rules: [
          ...baseline.rules.where(
            (rule) => rule.domain != AiroDataDomain.favorites,
          ),
          duplicate,
        ],
      );

      final result = matrix.validate();

      expect(
        result,
        contains(AiroDataOwnershipValidationCode.missingDomainRule),
      );
      expect(
        result,
        contains(AiroDataOwnershipValidationCode.duplicateDomainRule),
      );
    });

    test('public maps expose stable ids and no raw media values', () {
      final publicMap = AiroTvProfileDataOwnershipMatrices.liteReceiver()
          .toPublicMap();
      final flattened = publicMap.toString();

      expect(publicMap['profile'], AiroDataProfile.liteReceiver.stableId);
      expect(flattened, contains(AiroDataDomain.playlistIndex.stableId));
      expect(
        flattened,
        contains(AiroDataStorageScope.delegatedReadOnly.stableId),
      );
      expect(flattened, isNot(contains('/Users/')));
      expect(flattened, isNot(contains('providerPayload')));
      expect(flattened, isNot(contains('storeConsoleAccount')));
      expect(flattened, isNot(contains('rawCredential')));
      expect(flattened, isNot(contains('http://')));
    });
  });
}

AiroProfileDataOwnershipMatrix _invalidMatrixWith(
  AiroProfileDataOwnershipRule replacement,
) {
  final baseline = AiroTvProfileDataOwnershipMatrices.fullTv();
  return AiroProfileDataOwnershipMatrix(
    profile: AiroDataProfile.fullTv,
    rules: [
      ...baseline.rules.where((rule) => rule.domain != replacement.domain),
      replacement,
    ],
  );
}

AiroProfileDataOwnershipMatrix _liteMatrixWith(
  AiroProfileDataOwnershipRule replacement,
) {
  final baseline = AiroTvProfileDataOwnershipMatrices.liteReceiver();
  return AiroProfileDataOwnershipMatrix(
    profile: AiroDataProfile.liteReceiver,
    rules: [
      ...baseline.rules.where((rule) => rule.domain != replacement.domain),
      replacement,
    ],
  );
}
