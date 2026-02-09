import 'package:core_domain/src/plugins/manifest_validator.dart';
import 'package:core_domain/src/plugins/plugin_manifest.dart';
import 'package:core_domain/src/plugins/plugin_loader_service.dart';
import 'package:core_domain/src/plugins/plugin_downloader_service.dart';
import 'package:core_domain/src/plugins/plugin_storage_service.dart';
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

  group('PluginLoadResult', () {
    test('success factory creates successful result', () {
      final result = PluginLoadResult.success('com.test.plugin', '1.0.0');

      expect(result.pluginId, 'com.test.plugin');
      expect(result.success, isTrue);
      expect(result.loadedVersion, '1.0.0');
      expect(result.errorMessage, isNull);
    });

    test('failure factory creates failed result', () {
      final result = PluginLoadResult.failure('com.test.plugin', 'Load failed');

      expect(result.pluginId, 'com.test.plugin');
      expect(result.success, isFalse);
      expect(result.errorMessage, 'Load failed');
      expect(result.loadedVersion, isNull);
    });
  });

  group('PluginState', () {
    test('enum has all expected values', () {
      expect(
        PluginState.values,
        containsAll([
          PluginState.notInstalled,
          PluginState.downloading,
          PluginState.installed,
          PluginState.loading,
          PluginState.loaded,
          PluginState.updating,
          PluginState.uninstalling,
          PluginState.error,
          PluginState.disabled,
        ]),
      );
    });
  });

  group('DownloadProgress', () {
    test('starting factory creates pending progress', () {
      final progress = DownloadProgress.starting('com.test.plugin');

      expect(progress.pluginId, 'com.test.plugin');
      expect(progress.status, DownloadStatus.pending);
      expect(progress.totalBytes, 0);
      expect(progress.downloadedBytes, 0);
      expect(progress.progress, 0.0);
    });

    test('completed factory creates completed progress', () {
      final progress = DownloadProgress.completed('com.test.plugin', 1000);

      expect(progress.pluginId, 'com.test.plugin');
      expect(progress.status, DownloadStatus.completed);
      expect(progress.totalBytes, 1000);
      expect(progress.downloadedBytes, 1000);
      expect(progress.isComplete, isTrue);
      expect(progress.progress, 1.0);
      expect(progress.progressPercent, 100);
    });

    test('failed factory creates failed progress', () {
      final progress = DownloadProgress.failed('com.test.plugin', 'Error');

      expect(progress.pluginId, 'com.test.plugin');
      expect(progress.status, DownloadStatus.failed);
      expect(progress.isFailed, isTrue);
      expect(progress.error, 'Error');
    });

    test('progress calculation works correctly', () {
      const progress = DownloadProgress(
        pluginId: 'com.test.plugin',
        totalBytes: 1000,
        downloadedBytes: 500,
        status: DownloadStatus.downloading,
      );

      expect(progress.progress, 0.5);
      expect(progress.progressPercent, 50);
      expect(progress.isInProgress, isTrue);
    });

    test('handles zero totalBytes gracefully', () {
      const progress = DownloadProgress(
        pluginId: 'com.test.plugin',
        totalBytes: 0,
        downloadedBytes: 0,
        status: DownloadStatus.pending,
      );

      expect(progress.progress, 0.0);
      expect(progress.progressPercent, 0);
    });
  });

  group('VerificationResult', () {
    test('valid factory creates valid result', () {
      final result = VerificationResult.valid('com.test.plugin');

      expect(result.pluginId, 'com.test.plugin');
      expect(result.isValid, isTrue);
      expect(result.errorMessage, isNull);
    });

    test('invalid factory creates invalid result', () {
      final result = VerificationResult.invalid(
        'com.test.plugin',
        'Bad checksum',
      );

      expect(result.pluginId, 'com.test.plugin');
      expect(result.isValid, isFalse);
      expect(result.errorMessage, 'Bad checksum');
    });
  });

  group('StoredPluginInfo', () {
    late PluginManifest testManifest;

    setUp(() {
      testManifest = PluginManifest(
        schemaVersion: '1.0',
        id: 'com.test.plugin',
        name: 'Test Plugin',
        version: '1.0.0',
        sizeMb: 5.0,
        minAppVersion: '1.0.0',
        entryPoint: 'test.dart',
        initFunction: 'initTest',
        permissions: [],
        dependencies: [],
        checksums: const PluginChecksums(
          sha256:
              'abc123def456abc123def456abc123def456abc123def456abc123def456abc1',
        ),
      );
    });

    test('shortcuts return correct values', () {
      final info = StoredPluginInfo(
        manifest: testManifest,
        installedAt: DateTime(2024, 1, 1),
        storagePath: '/path/to/plugin',
        sizeBytes: 5000000,
        isEnabled: true,
      );

      expect(info.pluginId, 'com.test.plugin');
      expect(info.version, '1.0.0');
      expect(info.isEnabled, isTrue);
    });
  });

  group('LoadedPluginInfo', () {
    late PluginManifest testManifest;

    setUp(() {
      testManifest = PluginManifest(
        schemaVersion: '1.0',
        id: 'com.test.plugin',
        name: 'Test Plugin',
        version: '1.0.0',
        sizeMb: 5.0,
        minAppVersion: '1.0.0',
        entryPoint: 'test.dart',
        initFunction: 'initTest',
        permissions: [],
        dependencies: [],
        checksums: const PluginChecksums(
          sha256:
              'abc123def456abc123def456abc123def456abc123def456abc123def456abc1',
        ),
      );
    });

    test('creates loaded plugin info correctly', () {
      final now = DateTime.now();
      final info = LoadedPluginInfo(
        manifest: testManifest,
        state: PluginState.loaded,
        installedAt: now,
        lastLoadedAt: now,
      );

      expect(info.manifest, testManifest);
      expect(info.state, PluginState.loaded);
      expect(info.error, isNull);
    });

    test('error state includes error message', () {
      final info = LoadedPluginInfo(
        manifest: testManifest,
        state: PluginState.error,
        installedAt: DateTime.now(),
        error: 'Failed to load',
      );

      expect(info.state, PluginState.error);
      expect(info.error, 'Failed to load');
    });
  });
}
