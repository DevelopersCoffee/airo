import 'package:core_domain/src/plugins/manifest_validator.dart';
import 'package:core_domain/src/plugins/plugin_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PluginManifest', () {
    late Map<String, dynamic> validManifestJson;

    setUp(() {
      validManifestJson = {
        'schema_version': '1.0',
        'id': 'com.airo.plugin.beats',
        'name': 'Beats Music',
        'version': '1.2.0',
        'size_mb': 4.6,
        'min_app_version': '1.4.0',
        'entry_point': 'plugin_beats.dart',
        'init_function': 'initBeatsPlugin',
        'permissions': ['audio', 'network', 'background_audio'],
        'dependencies': ['core_audio>=1.0.0'],
        'checksums': {
          'sha256':
              'abc123def456abc123def456abc123def456abc123def456abc123def456abc1',
        },
        'metadata': {
          'description': 'Music streaming and offline playback',
          'icon': 'assets/icon.svg',
          'category': 'media',
          'tags': ['music', 'streaming', 'offline'],
        },
        'feature_flags': {
          'requires': ['beats_enabled'],
          'provides': ['music_player', 'audio_background'],
        },
      };
    });

    test('fromJson parses valid manifest correctly', () {
      final manifest = PluginManifest.fromJson(validManifestJson);

      expect(manifest.schemaVersion, '1.0');
      expect(manifest.id, 'com.airo.plugin.beats');
      expect(manifest.name, 'Beats Music');
      expect(manifest.version, '1.2.0');
      expect(manifest.sizeMb, 4.6);
      expect(manifest.minAppVersion, '1.4.0');
      expect(manifest.entryPoint, 'plugin_beats.dart');
      expect(manifest.initFunction, 'initBeatsPlugin');
      expect(manifest.permissions, [
        PluginPermission.audio,
        PluginPermission.network,
        PluginPermission.backgroundAudio,
      ]);
      expect(manifest.dependencies, ['core_audio>=1.0.0']);
    });

    test('toJson produces valid JSON', () {
      final manifest = PluginManifest.fromJson(validManifestJson);
      final json = manifest.toJson();

      expect(json['schema_version'], '1.0');
      expect(json['id'], 'com.airo.plugin.beats');
      expect(json['permissions'], ['audio', 'network', 'backgroundAudio']);
    });

    test('equality based on id and version', () {
      final manifest1 = PluginManifest.fromJson(validManifestJson);
      final manifest2 = PluginManifest.fromJson(validManifestJson);

      expect(manifest1, equals(manifest2));
      expect(manifest1.hashCode, equals(manifest2.hashCode));
    });
  });

  group('PluginPermission', () {
    test('fromString parses snake_case permission', () {
      expect(
        PluginPermission.fromString('background_audio'),
        PluginPermission.backgroundAudio,
      );
    });

    test('fromString parses camelCase permission', () {
      expect(
        PluginPermission.fromString('backgroundAudio'),
        PluginPermission.backgroundAudio,
      );
    });

    test('fromString throws for unknown permission', () {
      expect(
        () => PluginPermission.fromString('unknown_permission'),
        throwsArgumentError,
      );
    });
  });

  group('PluginRegistry', () {
    test('fromJson parses registry correctly', () {
      final json = {
        'version': '2026-02-09',
        'plugins': [
          {
            'id': 'com.airo.plugin.beats',
            'latest_version': '1.2.0',
            'download_url':
                'https://cdn.airo.app/plugins/beats/1.2.0/plugin.zip',
            'changelog_url': 'https://cdn.airo.app/plugins/beats/CHANGELOG.md',
          },
          {
            'id': 'com.airo.plugin.games',
            'latest_version': '1.0.0',
            'download_url':
                'https://cdn.airo.app/plugins/games/1.0.0/plugin.zip',
          },
        ],
      };

      final registry = PluginRegistry.fromJson(json);

      expect(registry.version, '2026-02-09');
      expect(registry.plugins.length, 2);
      expect(
        registry.findById('com.airo.plugin.beats')?.latestVersion,
        '1.2.0',
      );
      expect(registry.findById('com.airo.plugin.unknown'), isNull);
    });
  });

  group('ManifestValidator', () {
    late ManifestValidator validator;
    late Map<String, dynamic> validManifestJson;

    setUp(() {
      validator = const ManifestValidator();
      validManifestJson = {
        'schema_version': '1.0',
        'id': 'com.airo.plugin.beats',
        'name': 'Beats Music',
        'version': '1.2.0',
        'size_mb': 4.6,
        'min_app_version': '1.4.0',
        'entry_point': 'plugin_beats.dart',
        'init_function': 'initBeatsPlugin',
        'checksums': {
          'sha256':
              'abc123def456abc123def456abc123def456abc123def456abc123def456abc1',
        },
      };
    });

    test('validates valid manifest', () {
      final manifest = PluginManifest.fromJson(validManifestJson);
      final result = validator.validate(manifest);

      expect(result.isValid, isTrue);
      expect(result.errors, isEmpty);
    });

    test('rejects invalid plugin ID format', () {
      validManifestJson['id'] = 'invalid-id';
      final manifest = PluginManifest.fromJson(validManifestJson);
      final result = validator.validate(manifest);

      expect(result.isValid, isFalse);
      expect(result.errors, contains(contains('Invalid plugin ID format')));
    });

    test('rejects plugin ID not starting with com.airo.plugin', () {
      validManifestJson['id'] = 'org.example.plugin.test';
      final manifest = PluginManifest.fromJson(validManifestJson);
      final result = validator.validate(manifest);

      expect(result.isValid, isFalse);
      expect(
        result.errors,
        contains(contains('must start with "com.airo.plugin."')),
      );
    });

    test('rejects invalid semantic version', () {
      validManifestJson['version'] = '1.0';
      final manifest = PluginManifest.fromJson(validManifestJson);
      final result = validator.validate(manifest);

      expect(result.isValid, isFalse);
      expect(result.errors, contains(contains('Invalid version format')));
    });

    test('rejects invalid SHA-256 checksum', () {
      validManifestJson['checksums'] = {'sha256': 'invalid'};
      final manifest = PluginManifest.fromJson(validManifestJson);
      final result = validator.validate(manifest);

      expect(result.isValid, isFalse);
      expect(
        result.errors,
        contains(contains('Invalid SHA-256 checksum format')),
      );
    });

    test('rejects entry point without .dart extension', () {
      validManifestJson['entry_point'] = 'plugin_beats.js';
      final manifest = PluginManifest.fromJson(validManifestJson);
      final result = validator.validate(manifest);

      expect(result.isValid, isFalse);
      expect(result.errors, contains(contains('must be a .dart file')));
    });

    test('rejects negative size', () {
      validManifestJson['size_mb'] = -1.0;
      final manifest = PluginManifest.fromJson(validManifestJson);
      final result = validator.validate(manifest);

      expect(result.isValid, isFalse);
      expect(result.errors, contains(contains('Size must be positive')));
    });

    test('validates registry correctly', () {
      final registry = PluginRegistry.fromJson({
        'version': '2026-02-09',
        'plugins': [
          {
            'id': 'com.airo.plugin.beats',
            'latest_version': '1.0.0',
            'download_url': 'https://cdn.airo.app/plugins/beats.zip',
          },
        ],
      });

      final result = validator.validateRegistry(registry);
      expect(result.isValid, isTrue);
    });

    test('rejects invalid registry version format', () {
      final registry = PluginRegistry.fromJson({
        'version': 'invalid',
        'plugins': [],
      });

      final result = validator.validateRegistry(registry);
      expect(result.isValid, isFalse);
      expect(
        result.errors,
        contains(contains('Invalid registry version format')),
      );
    });
  });
}
