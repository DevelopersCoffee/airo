import 'package:core_ai/core_ai.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SkillPackage schema', () {
    test(
      'round-trips package metadata, permissions, provenance, and eval cases',
      () {
        final package = SkillPackage.fromJson(_validPackageJson());

        expect(package.schemaVersion, kSkillPackageSchemaVersion);
        expect(package.id, 'com.airo.skills.calendar_planner');
        expect(package.permissions, [
          const SkillPermission(
            scope: SkillPermissionScope.calendar,
            trustTier: SkillTrustTier.confirmationRequired,
            reason: 'Create calendar holds after user approval',
          ),
          const SkillPermission(
            scope: SkillPermissionScope.network,
            trustTier: SkillTrustTier.readOnly,
            reason: 'Read availability from configured calendar providers',
          ),
        ]);
        expect(package.provenance.source, SkillProvenanceSource.builtIn);
        expect(
          package.evalCases.single.expectedDecision,
          SkillEvalExpectedDecision.allow,
        );

        final restored = SkillPackage.fromJson(package.toJson());
        expect(restored.toJson(), package.toJson());
      },
    );

    test(
      'rejects missing required metadata with deterministic user-facing errors',
      () {
        final json = _validPackageJson()
          ..remove('name')
          ..['permissions'] = [
            {'scope': 'unsupported_scope', 'trust_tier': 'auto_approved'},
          ];

        final result = SkillPackage.validateJson(json);

        expect(result.isValid, isFalse);
        expect(result.errors, contains('name is required'));
        expect(
          result.errors,
          contains('permissions[0].scope is unsupported: unsupported_scope'),
        );
      },
    );

    test('rejects activation when provenance or eval metadata is missing', () {
      final json = _validPackageJson()
        ..remove('provenance')
        ..['eval_cases'] = <Map<String, dynamic>>[];

      final result = SkillPackage.validateJson(json);

      expect(result.isValid, isFalse);
      expect(result.errors, contains('provenance is required'));
      expect(result.errors, contains('at least one eval case is required'));
    });
  });

  group('SkillRegistryEntry schema', () {
    test(
      'stores version, provenance, trust tier, review status, and eval status',
      () {
        final entry = SkillRegistryEntry.fromJson({
          'schema_version': kSkillRegistrySchemaVersion,
          'package_id': 'com.airo.skills.calendar_planner',
          'version': '1.0.0',
          'display_name': 'Calendar Planner',
          'provenance': _validProvenanceJson(),
          'trust_tier': 'draft_only',
          'review_status': 'security_review_required',
          'eval_status': 'passing',
          'capability_profile_ids': ['routine-planner-local'],
          'installed_at': '2026-06-27T10:00:00.000Z',
          'enabled': false,
        });

        expect(entry.packageId, 'com.airo.skills.calendar_planner');
        expect(entry.trustTier, SkillTrustTier.draftOnly);
        expect(entry.reviewStatus, SkillReviewStatus.securityReviewRequired);
        expect(entry.evalStatus, SkillEvalStatus.passing);
        expect(entry.provenance.source, SkillProvenanceSource.builtIn);
        expect(entry.toJson()['enabled'], false);
      },
    );
  });

  group('CapabilityProfile schema', () {
    test('bundles runtime params, allowed skills, tools, and permissions', () {
      final profile = CapabilityProfile.fromJson({
        'schema_version': kCapabilityProfileSchemaVersion,
        'id': 'routine-planner-local',
        'name': 'Routine Planner Local',
        'model_runtime': {
          'provider': 'litert',
          'model_id': 'gemma-3n-e2b-it-litertlm',
          'temperature': 0.2,
          'max_output_tokens': 1024,
          'local_only': true,
        },
        'allowed_skill_ids': ['com.airo.skills.calendar_planner'],
        'allowed_tool_scopes': ['calendar', 'file_system'],
        'permission_defaults': [
          {'scope': 'calendar', 'trust_tier': 'confirmation_required'},
          {'scope': 'file_system', 'trust_tier': 'draft_only'},
        ],
        'network_policy': 'blocked',
      });

      expect(profile.modelRuntime.provider, 'litert');
      expect(profile.modelRuntime.localOnly, isTrue);
      expect(profile.allowedSkillIds, ['com.airo.skills.calendar_planner']);
      expect(profile.allowedToolScopes, [
        SkillPermissionScope.calendar,
        SkillPermissionScope.fileSystem,
      ]);
      expect(profile.networkPolicy, CapabilityNetworkPolicy.blocked);
      expect(
        profile.permissionDefaults.first.trustTier,
        SkillTrustTier.confirmationRequired,
      );
    });
  });
}

Map<String, dynamic> _validPackageJson() => {
  'schema_version': kSkillPackageSchemaVersion,
  'id': 'com.airo.skills.calendar_planner',
  'name': 'Calendar Planner',
  'version': '1.0.0',
  'description': 'Plans calendar-safe routines.',
  'author': 'Airo Framework Agent',
  'license': 'Apache-2.0',
  'entry_point': 'skills/calendar_planner/skill.md',
  'capability_profile_ids': ['routine-planner-local'],
  'permissions': [
    {
      'scope': 'calendar',
      'trust_tier': 'confirmation_required',
      'reason': 'Create calendar holds after user approval',
    },
    {
      'scope': 'network',
      'trust_tier': 'read_only',
      'reason': 'Read availability from configured calendar providers',
    },
  ],
  'provenance': _validProvenanceJson(),
  'eval_cases': [
    {
      'id': 'calendar-no-side-effect-without-confirmation',
      'prompt': 'Plan my week and add tentative holds.',
      'expected_decision': 'allow',
      'required_assertions': [
        'calendar write actions require confirmation',
        'no prompt text is stored in registry events',
      ],
    },
  ],
};

Map<String, dynamic> _validProvenanceJson() => {
  'source': 'built_in',
  'publisher': 'DevelopersCoffee',
  'reviewed_by': ['Framework Agent', 'Security and Privacy Agent'],
  'source_uri': 'https://github.com/DevelopersCoffee/airo',
  'checksum_sha256':
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
};
