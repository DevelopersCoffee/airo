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
