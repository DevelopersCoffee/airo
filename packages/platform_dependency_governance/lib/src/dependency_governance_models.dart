import 'package:equatable/equatable.dart';

const String kAiroDependencyGovernanceSchemaVersion = '1.0.0';

enum AiroDependencyImportance {
  required('required'),
  optional('optional'),
  developmentOnly('development_only');

  const AiroDependencyImportance(this.stableId);

  final String stableId;
}

enum AiroNativeArchitecture {
  arm64('arm64'),
  armeabiV7a('armeabi_v7a'),
  x64('x64'),
  x86('x86');

  const AiroNativeArchitecture(this.stableId);

  final String stableId;
}

enum AiroDependencyBlockerCode {
  missingAndroidApiFloor('missing_android_api_floor'),
  raisesAndroidApiFloor('raises_android_api_floor'),
  missingFallbackForRaisedApi('missing_fallback_for_raised_api'),
  missingNativeArchitectures('missing_native_architectures'),
  binarySizeBudgetExceeded('binary_size_budget_exceeded'),
  memoryBudgetExceeded('memory_budget_exceeded'),
  backgroundBehaviorUndeclared('background_behavior_undeclared'),
  shrinkerRulesMissing('shrinker_rules_missing'),
  tvIssuesNotReviewed('tv_issues_not_reviewed'),
  ownerMissing('owner_missing');

  const AiroDependencyBlockerCode(this.stableId);

  final String stableId;
}

class AiroDependencyAuditRecord extends Equatable {
  AiroDependencyAuditRecord({
    required this.packageName,
    required this.version,
    required this.usedByModule,
    required this.importance,
    required this.minimumAndroidApi,
    Set<AiroNativeArchitecture> nativeArchitectures = const {},
    this.hasNativeCode = false,
    this.estimatedBinarySizeKb,
    this.estimatedRuntimeMemoryMb,
    this.hasBackgroundBehavior = false,
    this.backgroundBehavior,
    this.requiresShrinkerRules = false,
    this.shrinkerRulesValidated = false,
    this.tvIssuesReviewed = false,
    this.hasFallbackOrStub = false,
    this.maintenanceOwner,
    this.schemaVersion = kAiroDependencyGovernanceSchemaVersion,
  }) : nativeArchitectures = Set.unmodifiable(nativeArchitectures);

  final String schemaVersion;
  final String packageName;
  final String version;
  final String usedByModule;
  final AiroDependencyImportance importance;
  final int? minimumAndroidApi;
  final bool hasNativeCode;
  final Set<AiroNativeArchitecture> nativeArchitectures;
  final int? estimatedBinarySizeKb;
  final int? estimatedRuntimeMemoryMb;
  final bool hasBackgroundBehavior;
  final String? backgroundBehavior;
  final bool requiresShrinkerRules;
  final bool shrinkerRulesValidated;
  final bool tvIssuesReviewed;
  final bool hasFallbackOrStub;
  final String? maintenanceOwner;

  bool get isOptional =>
      importance == AiroDependencyImportance.optional ||
      importance == AiroDependencyImportance.developmentOnly;

  @override
  List<Object?> get props => [
    schemaVersion,
    packageName,
    version,
    usedByModule,
    importance,
    minimumAndroidApi,
    hasNativeCode,
    nativeArchitectures,
    estimatedBinarySizeKb,
    estimatedRuntimeMemoryMb,
    hasBackgroundBehavior,
    backgroundBehavior,
    requiresShrinkerRules,
    shrinkerRulesValidated,
    tvIssuesReviewed,
    hasFallbackOrStub,
    maintenanceOwner,
  ];
}

class AiroDependencyGovernanceChecklist extends Equatable {
  const AiroDependencyGovernanceChecklist({
    this.androidApiBaseline = 26,
    this.maxBinarySizeKb = 4096,
    this.maxRuntimeMemoryMb = 32,
    this.schemaVersion = kAiroDependencyGovernanceSchemaVersion,
  });

  final String schemaVersion;
  final int androidApiBaseline;
  final int maxBinarySizeKb;
  final int maxRuntimeMemoryMb;

  AiroDependencyGovernanceResult evaluate(AiroDependencyAuditRecord record) {
    final blockers = <AiroDependencyBlocker>[];

    final apiFloor = record.minimumAndroidApi;
    if (apiFloor == null) {
      blockers.add(
        AiroDependencyBlocker(
          packageName: record.packageName,
          code: AiroDependencyBlockerCode.missingAndroidApiFloor,
        ),
      );
    } else if (apiFloor > androidApiBaseline) {
      if (!record.isOptional || !record.hasFallbackOrStub) {
        blockers.add(
          AiroDependencyBlocker(
            packageName: record.packageName,
            code: AiroDependencyBlockerCode.raisesAndroidApiFloor,
          ),
        );
        blockers.add(
          AiroDependencyBlocker(
            packageName: record.packageName,
            code: AiroDependencyBlockerCode.missingFallbackForRaisedApi,
          ),
        );
      }
    }

    if (record.hasNativeCode && record.nativeArchitectures.isEmpty) {
      blockers.add(
        AiroDependencyBlocker(
          packageName: record.packageName,
          code: AiroDependencyBlockerCode.missingNativeArchitectures,
        ),
      );
    }

    final binarySize = record.estimatedBinarySizeKb;
    if (binarySize != null && binarySize > maxBinarySizeKb) {
      blockers.add(
        AiroDependencyBlocker(
          packageName: record.packageName,
          code: AiroDependencyBlockerCode.binarySizeBudgetExceeded,
        ),
      );
    }

    final runtimeMemory = record.estimatedRuntimeMemoryMb;
    if (runtimeMemory != null && runtimeMemory > maxRuntimeMemoryMb) {
      blockers.add(
        AiroDependencyBlocker(
          packageName: record.packageName,
          code: AiroDependencyBlockerCode.memoryBudgetExceeded,
        ),
      );
    }

    if (record.hasBackgroundBehavior &&
        (record.backgroundBehavior == null ||
            record.backgroundBehavior!.trim().isEmpty)) {
      blockers.add(
        AiroDependencyBlocker(
          packageName: record.packageName,
          code: AiroDependencyBlockerCode.backgroundBehaviorUndeclared,
        ),
      );
    }

    if (record.requiresShrinkerRules && !record.shrinkerRulesValidated) {
      blockers.add(
        AiroDependencyBlocker(
          packageName: record.packageName,
          code: AiroDependencyBlockerCode.shrinkerRulesMissing,
        ),
      );
    }

    if (!record.tvIssuesReviewed) {
      blockers.add(
        AiroDependencyBlocker(
          packageName: record.packageName,
          code: AiroDependencyBlockerCode.tvIssuesNotReviewed,
        ),
      );
    }

    if (record.maintenanceOwner == null ||
        record.maintenanceOwner!.trim().isEmpty) {
      blockers.add(
        AiroDependencyBlocker(
          packageName: record.packageName,
          code: AiroDependencyBlockerCode.ownerMissing,
        ),
      );
    }

    return AiroDependencyGovernanceResult(
      packageName: record.packageName,
      blockers: blockers,
    );
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    androidApiBaseline,
    maxBinarySizeKb,
    maxRuntimeMemoryMb,
  ];
}

class AiroDependencyBlocker extends Equatable {
  const AiroDependencyBlocker({required this.packageName, required this.code});

  final String packageName;
  final AiroDependencyBlockerCode code;

  @override
  List<Object?> get props => [packageName, code];
}

class AiroDependencyGovernanceResult extends Equatable {
  AiroDependencyGovernanceResult({
    required this.packageName,
    required List<AiroDependencyBlocker> blockers,
  }) : blockers = List.unmodifiable(blockers);

  final String packageName;
  final List<AiroDependencyBlocker> blockers;

  bool get passed => blockers.isEmpty;

  @override
  List<Object?> get props => [packageName, blockers];
}

class AiroDependencyGovernanceAudit extends Equatable {
  AiroDependencyGovernanceAudit({
    required this.auditId,
    required this.releaseLine,
    required this.targetProfile,
    required List<AiroDependencyAuditRecord> records,
    required this.createdAt,
    this.schemaVersion = kAiroDependencyGovernanceSchemaVersion,
  }) : records = List.unmodifiable(records);

  final String schemaVersion;
  final String auditId;
  final String releaseLine;
  final String targetProfile;
  final List<AiroDependencyAuditRecord> records;
  final DateTime createdAt;

  AiroDependencyGovernanceAuditReport evaluate({
    AiroDependencyGovernanceChecklist checklist =
        const AiroDependencyGovernanceChecklist(),
    required DateTime generatedAt,
  }) {
    final results = records.map(checklist.evaluate).toList(growable: false);

    return AiroDependencyGovernanceAuditReport(
      auditId: auditId,
      releaseLine: releaseLine,
      targetProfile: targetProfile,
      checklist: checklist,
      results: results,
      createdAt: createdAt,
      generatedAt: generatedAt,
      schemaVersion: schemaVersion,
    );
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    auditId,
    releaseLine,
    targetProfile,
    records,
    createdAt,
  ];
}

class AiroDependencyGovernanceAuditReport extends Equatable {
  AiroDependencyGovernanceAuditReport({
    required this.auditId,
    required this.releaseLine,
    required this.targetProfile,
    required this.checklist,
    required List<AiroDependencyGovernanceResult> results,
    required this.createdAt,
    required this.generatedAt,
    this.schemaVersion = kAiroDependencyGovernanceSchemaVersion,
  }) : results = List.unmodifiable(results);

  final String schemaVersion;
  final String auditId;
  final String releaseLine;
  final String targetProfile;
  final AiroDependencyGovernanceChecklist checklist;
  final List<AiroDependencyGovernanceResult> results;
  final DateTime createdAt;
  final DateTime generatedAt;

  bool get passed => results.every((result) => result.passed);

  List<String> get blockedPackages {
    return List.unmodifiable(
      results
          .where((result) => !result.passed)
          .map((result) => result.packageName),
    );
  }

  Set<AiroDependencyBlockerCode> get blockerCodes {
    return Set.unmodifiable(
      results.expand(
        (result) => result.blockers.map((blocker) => blocker.code),
      ),
    );
  }

  Map<String, Object?> toPublicMap() {
    return {
      'schemaVersion': schemaVersion,
      'auditId': auditId,
      'releaseLine': releaseLine,
      'targetProfile': targetProfile,
      'passed': passed,
      'blockedPackages': blockedPackages,
      'blockerCodes': blockerCodes
          .map((code) => code.stableId)
          .toList(growable: false),
      'checklist': {
        'androidApiBaseline': checklist.androidApiBaseline,
        'maxBinarySizeKb': checklist.maxBinarySizeKb,
        'maxRuntimeMemoryMb': checklist.maxRuntimeMemoryMb,
      },
      'results': results.map(_resultToPublicMap).toList(growable: false),
      'createdAt': createdAt.toIso8601String(),
      'generatedAt': generatedAt.toIso8601String(),
    };
  }

  Map<String, Object?> _resultToPublicMap(
    AiroDependencyGovernanceResult result,
  ) {
    return {
      'packageName': result.packageName,
      'passed': result.passed,
      'blockers': result.blockers
          .map(
            (blocker) => {
              'packageName': blocker.packageName,
              'code': blocker.code.stableId,
            },
          )
          .toList(growable: false),
    };
  }

  @override
  List<Object?> get props => [
    schemaVersion,
    auditId,
    releaseLine,
    targetProfile,
    checklist,
    results,
    createdAt,
    generatedAt,
  ];
}
