import 'dart:convert';
import 'dart:io';

import 'package:core_release/core_release.dart';

void main(List<String> args) {
  if (args.contains('--help') || args.contains('-h')) {
    _printUsage();
    return;
  }

  final options = _parseOptions(args);
  final repoRoot = _repoRoot(options['repo-root']);
  final outputJson = options['output-json'];
  final outputMarkdown = options['output-markdown'];
  final pubspecPath = options['tv-pubspec'] ?? 'app/pubspec_tv.yaml';
  final manifestPath =
      options['tv-manifest'] ?? 'app/android/app/src/tv/AndroidManifest.xml';
  final pubspec = _readOptional(repoRoot, pubspecPath);
  final manifest = _readOptional(repoRoot, manifestPath);

  final preflight =
      AiroDataSafetyPreflightRunner(matrix: AiroReleaseMatrix.v2Default()).run(
        AiroDataSafetyPreflightRequest(
          profileId: options['profile'] ?? 'tv',
          analyticsSdkPresent:
              _optionFlag(options, 'analytics-sdk-present') ||
              _containsAny(pubspec, const ['firebase_analytics']),
          crashlyticsSdkPresent:
              _optionFlag(options, 'crashlytics-sdk-present') ||
              _containsAny(pubspec, const ['firebase_crashlytics']),
          advertisingSdkPresent:
              _optionFlag(options, 'advertising-sdk-present') ||
              _containsAny(pubspec, const [
                'google_mobile_ads',
                'firebase_admob',
                'app_tracking_transparency',
              ]) ||
              manifest.contains('com.google.android.gms.permission.AD_ID'),
          sensitiveAndroidPermissions: _sensitivePermissions(manifest),
          localPlaylistUrls: !_optionFlag(options, 'playlist-urls-not-local'),
          localPreferences: !_optionFlag(options, 'preferences-not-local'),
          localPlaybackState: !_optionFlag(options, 'playback-state-not-local'),
          accountRequiredForPlayback: _optionFlag(
            options,
            'account-required-for-playback',
          ),
          appStorePrivacyInScope: _optionFlag(
            options,
            'app-store-privacy-in-scope',
          ),
        ),
      );

  final encoded = const JsonEncoder.withIndent(
    '  ',
  ).convert(preflight.toPublicMap());
  stdout.writeln(encoded);

  if (outputJson != null) {
    _writeFile(repoRoot, outputJson, encoded);
  }
  if (outputMarkdown != null) {
    _writeFile(repoRoot, outputMarkdown, preflight.toMarkdown());
  }

  if (!preflight.readyForConsoleEntry) {
    exitCode = 1;
  }
}

Map<String, String> _parseOptions(List<String> args) {
  final options = <String, String>{};
  for (var index = 0; index < args.length; index += 1) {
    final arg = args[index];
    if (!arg.startsWith('--')) {
      stderr.writeln('Ignoring positional argument: $arg');
      continue;
    }
    final equals = arg.indexOf('=');
    if (equals > 0) {
      options[arg.substring(2, equals)] = arg.substring(equals + 1);
      continue;
    }
    final key = arg.substring(2);
    if (_booleanFlags.contains(key)) {
      options[key] = 'true';
      continue;
    }
    if (index + 1 >= args.length || args[index + 1].startsWith('--')) {
      throw ArgumentError('Missing value for --$key.');
    }
    options[key] = args[index + 1];
    index += 1;
  }
  return options;
}

const Set<String> _booleanFlags = {
  'analytics-sdk-present',
  'crashlytics-sdk-present',
  'advertising-sdk-present',
  'playlist-urls-not-local',
  'preferences-not-local',
  'playback-state-not-local',
  'account-required-for-playback',
  'app-store-privacy-in-scope',
};

Directory _repoRoot(String? configured) {
  if (configured != null && configured.trim().isNotEmpty) {
    return Directory(configured).absolute;
  }

  var current = Directory.current.absolute;
  while (true) {
    if (File('${current.path}/melos.yaml').existsSync()) {
      return current;
    }
    final parent = current.parent;
    if (parent.path == current.path) {
      return Directory.current.absolute;
    }
    current = parent;
  }
}

String _readOptional(Directory repoRoot, String path) {
  final file = File(path).isAbsolute
      ? File(path)
      : File('${repoRoot.path}/$path');
  if (!file.existsSync()) {
    return '';
  }
  return file.readAsStringSync();
}

bool _containsAny(String source, Iterable<String> needles) {
  return needles.any(source.contains);
}

bool _optionFlag(Map<String, String> options, String key) {
  final value = options[key];
  if (value == null) {
    return false;
  }
  final normalized = value.trim().toLowerCase();
  return normalized == '1' || normalized == 'true' || normalized == 'yes';
}

Set<String> _sensitivePermissions(String manifest) {
  final permissions = <String>{};
  for (final permission
      in AiroDataSafetyPreflightRunner.sensitivePermissionNames) {
    if (manifest.contains(permission)) {
      permissions.add(permission);
    }
  }
  return permissions;
}

void _writeFile(Directory repoRoot, String path, String contents) {
  final file = File(path).isAbsolute
      ? File(path)
      : File('${repoRoot.path}/$path');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(contents);
}

void _printUsage() {
  stdout.writeln('''
Preflight Airo TV Data Safety and App Privacy posture.

Usage:
  dart run tool/preflight_data_safety.dart [options]

Options:
  --profile <id>                         Release profile, default: tv
  --repo-root <path>                     Workspace root, auto-detected
  --tv-pubspec <path>                    TV pubspec path
  --tv-manifest <path>                   TV Android manifest path
  --analytics-sdk-present                Force Analytics SDK present
  --crashlytics-sdk-present              Force Crashlytics SDK present
  --advertising-sdk-present              Force advertising SDK present
  --playlist-urls-not-local              Mark playlist URLs as non-local
  --preferences-not-local                Mark preferences as non-local
  --playback-state-not-local             Mark playback state as non-local
  --account-required-for-playback        Mark account requirement present
  --app-store-privacy-in-scope           Include App Store Privacy labels
  --output-json <path>                   Write JSON report
  --output-markdown <path>               Write markdown report
  --help                                 Show this help
''');
}
