import 'package:meta/meta.dart';

/// Current version for skill package manifests.
const String kSkillPackageSchemaVersion = '1.0';

/// Current version for skill registry entries.
const String kSkillRegistrySchemaVersion = '1.0';

/// Current version for capability profiles.
const String kCapabilityProfileSchemaVersion = '1.0';

@immutable
class SkillSchemaValidationResult {
  const SkillSchemaValidationResult._(this.errors);

  const SkillSchemaValidationResult.valid() : this._(const []);
  const SkillSchemaValidationResult.invalid(List<String> errors)
    : this._(errors);

  final List<String> errors;

  bool get isValid => errors.isEmpty;
}

enum SkillTrustTier {
  readOnly,
  draftOnly,
  confirmationRequired,
  autoApproved,
  blocked;

  static SkillTrustTier fromJson(String value) =>
      _enumFromJson(values, value, 'trust tier');

  String toJson() => _camelToSnake(name);
}

enum SkillPermissionScope {
  calendar,
  contacts,
  fileSystem,
  location,
  memory,
  microphone,
  network,
  notifications,
  reminders,
  storage,
  toolExecution;

  static SkillPermissionScope fromJson(String value) =>
      _enumFromJson(values, value, 'permission scope');

  String toJson() => _camelToSnake(name);
}

enum SkillProvenanceSource {
  builtIn,
  community,
  localDraft,
  organization;

  static SkillProvenanceSource fromJson(String value) =>
      _enumFromJson(values, value, 'provenance source');

  String toJson() => _camelToSnake(name);
}

enum SkillEvalExpectedDecision {
  allow,
  deny,
  requireConfirmation,
  draftOnly;

  static SkillEvalExpectedDecision fromJson(String value) =>
      _enumFromJson(values, value, 'expected decision');

  String toJson() => _camelToSnake(name);
}

enum SkillReviewStatus {
  unreviewed,
  securityReviewRequired,
  qaReviewRequired,
  approved,
  rejected;

  static SkillReviewStatus fromJson(String value) =>
      _enumFromJson(values, value, 'review status');

  String toJson() => _camelToSnake(name);
}

enum SkillEvalStatus {
  notRun,
  passing,
  failing,
  waived;

  static SkillEvalStatus fromJson(String value) =>
      _enumFromJson(values, value, 'eval status');

  String toJson() => _camelToSnake(name);
}

enum CapabilityNetworkPolicy {
  blocked,
  readOnly,
  allowlisted;

  static CapabilityNetworkPolicy fromJson(String value) =>
      _enumFromJson(values, value, 'network policy');

  String toJson() => _camelToSnake(name);
}

@immutable
class SkillPermission {
  const SkillPermission({
    required this.scope,
    required this.trustTier,
    this.reason,
  });

  final SkillPermissionScope scope;
  final SkillTrustTier trustTier;
  final String? reason;

  factory SkillPermission.fromJson(Map<String, dynamic> json) {
    return SkillPermission(
      scope: SkillPermissionScope.fromJson(json['scope'] as String),
      trustTier: SkillTrustTier.fromJson(json['trust_tier'] as String),
      reason: json['reason'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'scope': scope.toJson(),
    'trust_tier': trustTier.toJson(),
    if (reason != null) 'reason': reason,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SkillPermission &&
          scope == other.scope &&
          trustTier == other.trustTier &&
          reason == other.reason;

  @override
  int get hashCode => Object.hash(scope, trustTier, reason);
}

@immutable
class SkillProvenance {
  const SkillProvenance({
    required this.source,
    required this.publisher,
    this.reviewedBy = const [],
    this.sourceUri,
    this.checksumSha256,
  });

  final SkillProvenanceSource source;
  final String publisher;
  final List<String> reviewedBy;
  final String? sourceUri;
  final String? checksumSha256;

  factory SkillProvenance.fromJson(Map<String, dynamic> json) {
    return SkillProvenance(
      source: SkillProvenanceSource.fromJson(json['source'] as String),
      publisher: json['publisher'] as String,
      reviewedBy: _stringList(json['reviewed_by']),
      sourceUri: json['source_uri'] as String?,
      checksumSha256: json['checksum_sha256'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'source': source.toJson(),
    'publisher': publisher,
    'reviewed_by': reviewedBy,
    if (sourceUri != null) 'source_uri': sourceUri,
    if (checksumSha256 != null) 'checksum_sha256': checksumSha256,
  };
}

@immutable
class SkillEvalCase {
  const SkillEvalCase({
    required this.id,
    required this.prompt,
    required this.expectedDecision,
    this.requiredAssertions = const [],
  });

  final String id;
  final String prompt;
  final SkillEvalExpectedDecision expectedDecision;
  final List<String> requiredAssertions;

  factory SkillEvalCase.fromJson(Map<String, dynamic> json) {
    return SkillEvalCase(
      id: json['id'] as String,
      prompt: json['prompt'] as String,
      expectedDecision: SkillEvalExpectedDecision.fromJson(
        json['expected_decision'] as String,
      ),
      requiredAssertions: _stringList(json['required_assertions']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'prompt': prompt,
    'expected_decision': expectedDecision.toJson(),
    'required_assertions': requiredAssertions,
  };
}

@immutable
class SkillPackage {
  const SkillPackage({
    required this.schemaVersion,
    required this.id,
    required this.name,
    required this.version,
    required this.description,
    required this.author,
    required this.license,
    required this.entryPoint,
    required this.provenance,
    this.capabilityProfileIds = const [],
    this.permissions = const [],
    this.evalCases = const [],
  });

  final String schemaVersion;
  final String id;
  final String name;
  final String version;
  final String description;
  final String author;
  final String license;
  final String entryPoint;
  final List<String> capabilityProfileIds;
  final List<SkillPermission> permissions;
  final SkillProvenance provenance;
  final List<SkillEvalCase> evalCases;

  factory SkillPackage.fromJson(Map<String, dynamic> json) {
    final validation = validateJson(json);
    if (!validation.isValid) {
      throw ArgumentError(validation.errors.join('; '));
    }

    return SkillPackage(
      schemaVersion: json['schema_version'] as String,
      id: json['id'] as String,
      name: json['name'] as String,
      version: json['version'] as String,
      description: json['description'] as String,
      author: json['author'] as String,
      license: json['license'] as String,
      entryPoint: json['entry_point'] as String,
      capabilityProfileIds: _stringList(json['capability_profile_ids']),
      permissions: _mapList(
        json['permissions'],
      ).map(SkillPermission.fromJson).toList(),
      provenance: SkillProvenance.fromJson(
        json['provenance'] as Map<String, dynamic>,
      ),
      evalCases: _mapList(
        json['eval_cases'],
      ).map(SkillEvalCase.fromJson).toList(),
    );
  }

  static SkillSchemaValidationResult validateJson(Map<String, dynamic> json) {
    final errors = <String>[];
    for (final key in [
      'schema_version',
      'id',
      'name',
      'version',
      'description',
      'author',
      'license',
      'entry_point',
    ]) {
      if (!_hasNonEmptyString(json, key)) errors.add('$key is required');
    }
    if (json['schema_version'] != null &&
        json['schema_version'] != kSkillPackageSchemaVersion) {
      errors.add('unsupported schema_version: ${json['schema_version']}');
    }
    if (json['provenance'] is! Map<String, dynamic>) {
      errors.add('provenance is required');
    }
    final evalCases = json['eval_cases'];
    if (evalCases is! List || evalCases.isEmpty) {
      errors.add('at least one eval case is required');
    }

    final permissions = json['permissions'];
    if (permissions is List) {
      for (var i = 0; i < permissions.length; i++) {
        final permission = permissions[i];
        if (permission is! Map<String, dynamic>) {
          errors.add('permissions[$i] must be an object');
          continue;
        }
        _validateEnumValue(
          SkillPermissionScope.values,
          permission['scope'],
          'permissions[$i].scope',
          errors,
        );
        _validateEnumValue(
          SkillTrustTier.values,
          permission['trust_tier'],
          'permissions[$i].trust_tier',
          errors,
        );
      }
    }

    return errors.isEmpty
        ? const SkillSchemaValidationResult.valid()
        : SkillSchemaValidationResult.invalid(errors);
  }

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'id': id,
    'name': name,
    'version': version,
    'description': description,
    'author': author,
    'license': license,
    'entry_point': entryPoint,
    'capability_profile_ids': capabilityProfileIds,
    'permissions': permissions
        .map((permission) => permission.toJson())
        .toList(),
    'provenance': provenance.toJson(),
    'eval_cases': evalCases.map((evalCase) => evalCase.toJson()).toList(),
  };
}

@immutable
class SkillRegistryEntry {
  const SkillRegistryEntry({
    required this.schemaVersion,
    required this.packageId,
    required this.version,
    required this.displayName,
    required this.provenance,
    required this.trustTier,
    required this.reviewStatus,
    required this.evalStatus,
    required this.installedAt,
    this.capabilityProfileIds = const [],
    this.enabled = false,
  });

  final String schemaVersion;
  final String packageId;
  final String version;
  final String displayName;
  final SkillProvenance provenance;
  final SkillTrustTier trustTier;
  final SkillReviewStatus reviewStatus;
  final SkillEvalStatus evalStatus;
  final List<String> capabilityProfileIds;
  final DateTime installedAt;
  final bool enabled;

  factory SkillRegistryEntry.fromJson(Map<String, dynamic> json) {
    return SkillRegistryEntry(
      schemaVersion: json['schema_version'] as String,
      packageId: json['package_id'] as String,
      version: json['version'] as String,
      displayName: json['display_name'] as String,
      provenance: SkillProvenance.fromJson(
        json['provenance'] as Map<String, dynamic>,
      ),
      trustTier: SkillTrustTier.fromJson(json['trust_tier'] as String),
      reviewStatus: SkillReviewStatus.fromJson(json['review_status'] as String),
      evalStatus: SkillEvalStatus.fromJson(json['eval_status'] as String),
      capabilityProfileIds: _stringList(json['capability_profile_ids']),
      installedAt: DateTime.parse(json['installed_at'] as String),
      enabled: json['enabled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'package_id': packageId,
    'version': version,
    'display_name': displayName,
    'provenance': provenance.toJson(),
    'trust_tier': trustTier.toJson(),
    'review_status': reviewStatus.toJson(),
    'eval_status': evalStatus.toJson(),
    'capability_profile_ids': capabilityProfileIds,
    'installed_at': installedAt.toUtc().toIso8601String(),
    'enabled': enabled,
  };
}

@immutable
class CapabilityProfile {
  const CapabilityProfile({
    required this.schemaVersion,
    required this.id,
    required this.name,
    required this.modelRuntime,
    required this.networkPolicy,
    this.allowedSkillIds = const [],
    this.allowedToolScopes = const [],
    this.permissionDefaults = const [],
  });

  final String schemaVersion;
  final String id;
  final String name;
  final CapabilityModelRuntime modelRuntime;
  final List<String> allowedSkillIds;
  final List<SkillPermissionScope> allowedToolScopes;
  final List<SkillPermission> permissionDefaults;
  final CapabilityNetworkPolicy networkPolicy;

  factory CapabilityProfile.fromJson(Map<String, dynamic> json) {
    return CapabilityProfile(
      schemaVersion: json['schema_version'] as String,
      id: json['id'] as String,
      name: json['name'] as String,
      modelRuntime: CapabilityModelRuntime.fromJson(
        json['model_runtime'] as Map<String, dynamic>,
      ),
      allowedSkillIds: _stringList(json['allowed_skill_ids']),
      allowedToolScopes: _stringList(
        json['allowed_tool_scopes'],
      ).map(SkillPermissionScope.fromJson).toList(),
      permissionDefaults: _mapList(
        json['permission_defaults'],
      ).map(SkillPermission.fromJson).toList(),
      networkPolicy: CapabilityNetworkPolicy.fromJson(
        json['network_policy'] as String,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'id': id,
    'name': name,
    'model_runtime': modelRuntime.toJson(),
    'allowed_skill_ids': allowedSkillIds,
    'allowed_tool_scopes': allowedToolScopes
        .map((scope) => scope.toJson())
        .toList(),
    'permission_defaults': permissionDefaults
        .map((permission) => permission.toJson())
        .toList(),
    'network_policy': networkPolicy.toJson(),
  };
}

@immutable
class CapabilityModelRuntime {
  const CapabilityModelRuntime({
    required this.provider,
    required this.modelId,
    this.temperature,
    this.maxOutputTokens,
    this.localOnly = true,
  });

  final String provider;
  final String modelId;
  final double? temperature;
  final int? maxOutputTokens;
  final bool localOnly;

  factory CapabilityModelRuntime.fromJson(Map<String, dynamic> json) {
    return CapabilityModelRuntime(
      provider: json['provider'] as String,
      modelId: json['model_id'] as String,
      temperature: (json['temperature'] as num?)?.toDouble(),
      maxOutputTokens: json['max_output_tokens'] as int?,
      localOnly: json['local_only'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'provider': provider,
    'model_id': modelId,
    if (temperature != null) 'temperature': temperature,
    if (maxOutputTokens != null) 'max_output_tokens': maxOutputTokens,
    'local_only': localOnly,
  };
}

bool _hasNonEmptyString(Map<String, dynamic> json, String key) =>
    json[key] is String && (json[key] as String).trim().isNotEmpty;

List<String> _stringList(Object? value) =>
    (value as List<dynamic>?)?.map((item) => item as String).toList() ??
    const [];

List<Map<String, dynamic>> _mapList(Object? value) =>
    (value as List<dynamic>?)
        ?.map((item) => item as Map<String, dynamic>)
        .toList() ??
    const [];

T _enumFromJson<T extends Enum>(List<T> values, String value, String label) {
  return values.firstWhere(
    (entry) => entry.name == value || _camelToSnake(entry.name) == value,
    orElse: () => throw ArgumentError('Unknown $label: $value'),
  );
}

void _validateEnumValue<T extends Enum>(
  List<T> values,
  Object? value,
  String path,
  List<String> errors,
) {
  if (value is! String) {
    errors.add('$path is required');
    return;
  }
  final supported = values.any(
    (entry) => entry.name == value || _camelToSnake(entry.name) == value,
  );
  if (!supported) errors.add('$path is unsupported: $value');
}

String _camelToSnake(String value) {
  return value
      .replaceAllMapped(
        RegExp('([a-z0-9])([A-Z])'),
        (match) => '${match.group(1)}_${match.group(2)}',
      )
      .toLowerCase();
}
