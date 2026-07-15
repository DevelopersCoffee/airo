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
  final profileId = options['profile'] ?? 'tv';
  final iosUploadInScope =
      options.containsKey('ios-upload-in-scope') ||
      _truthy(Platform.environment['AIRO_IOS_UPLOAD_IN_SCOPE']);
  final outputJson = options['output-json'];
  final outputMarkdown = options['output-markdown'];

  final configuredCredentialPath =
      Platform.environment['SUPPLY_JSON_KEY_FILE'] ??
      Platform.environment['SUPPLY_JSON_KEY'] ??
      'play-store-credentials.json';
  final credentialFileExists = _credentialFileExists(
    repoRoot: repoRoot,
    configuredPath: configuredCredentialPath,
  );

  final preflight =
      AiroFastlaneCredentialsPreflightRunner(
        matrix: AiroReleaseMatrix.v2Default(),
      ).run(
        AiroFastlaneCredentialsPreflightRequest(
          profileId: profileId,
          environment: Platform.environment,
          googlePlayCredentialFileExists: credentialFileExists,
          iosUploadInScope: iosUploadInScope,
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

  if (!preflight.googlePlayReady ||
      (iosUploadInScope && !preflight.appStoreConnectReady)) {
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
    if (key == 'ios-upload-in-scope') {
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

bool _credentialFileExists({
  required Directory repoRoot,
  required String configuredPath,
}) {
  final configured = File(configuredPath);
  if (configured.isAbsolute && configured.existsSync()) {
    return true;
  }

  final candidates = [
    File('${repoRoot.path}/$configuredPath'),
    File('${repoRoot.path}/app/android/$configuredPath'),
    File('${repoRoot.path}/app/android/fastlane/$configuredPath'),
  ];
  return candidates.any((candidate) => candidate.existsSync());
}

void _writeFile(Directory repoRoot, String path, String contents) {
  final file = File(path).isAbsolute
      ? File(path)
      : File('${repoRoot.path}/$path');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(contents);
}

bool _truthy(String? value) {
  if (value == null) {
    return false;
  }
  final normalized = value.trim().toLowerCase();
  return normalized == '1' || normalized == 'true' || normalized == 'yes';
}

void _printUsage() {
  stdout.writeln('''
Preflight Fastlane store credentials without printing secret values.

Usage:
  dart run tool/preflight_fastlane_credentials.dart [options]

Options:
  --profile <id>              Release profile to validate, default: tv
  --repo-root <path>          Workspace root, auto-detected by melos.yaml
  --ios-upload-in-scope       Treat App Store Connect credentials as blocking
  --output-json <path>        Write redacted JSON report
  --output-markdown <path>    Write markdown report
  --help                      Show this help
''');
}
