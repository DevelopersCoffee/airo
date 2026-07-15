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
  final productionSigning = _optionBool(
    options['production-signing'],
    fallback: _environmentBool(
      Platform.environment['PRODUCTION_SIGNING'],
      fallback: true,
    ),
  );
  final keystorePath =
      options['keystore-file'] ?? 'app/android/release.keystore';
  final preflight = const AiroAndroidSigningPreflightRunner().run(
    AiroAndroidSigningPreflightRequest(
      environment: Platform.environment,
      productionSigning: productionSigning,
      keystoreFileExists: _fileExists(repoRoot, keystorePath),
    ),
  );

  final encoded = const JsonEncoder.withIndent(
    '  ',
  ).convert(preflight.toPublicMap());
  stdout.writeln(encoded);

  final outputJson = options['output-json'];
  final outputMarkdown = options['output-markdown'];
  if (outputJson != null) {
    _writeFile(repoRoot, outputJson, encoded);
  }
  if (outputMarkdown != null) {
    _writeFile(repoRoot, outputMarkdown, preflight.toMarkdown());
  }

  if (!preflight.ready) {
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

bool _fileExists(Directory repoRoot, String path) {
  final file = File(path).isAbsolute
      ? File(path)
      : File('${repoRoot.path}/$path');
  return file.existsSync();
}

void _writeFile(Directory repoRoot, String path, String contents) {
  final file = File(path).isAbsolute
      ? File(path)
      : File('${repoRoot.path}/$path');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(contents);
}

bool _optionBool(String? value, {required bool fallback}) {
  if (value == null) return fallback;
  return _truthy(value);
}

bool _environmentBool(String? value, {required bool fallback}) {
  if (value == null || value.trim().isEmpty) return fallback;
  return _truthy(value);
}

bool _truthy(String? value) {
  if (value == null) return false;
  final normalized = value.trim().toLowerCase();
  return normalized == '1' || normalized == 'true' || normalized == 'yes';
}

void _printUsage() {
  stdout.writeln('''
Preflight Android release signing without printing secret values.

Usage:
  dart run tool/preflight_android_signing.dart [options]

Options:
  --repo-root <path>             Workspace root, auto-detected by melos.yaml
  --production-signing <bool>    Require production signing inputs, default: true
  --keystore-file <path>         Optional local release keystore path
  --output-json <path>           Write redacted JSON report
  --output-markdown <path>       Write markdown report
  --help                         Show this help

Required production inputs:
  ANDROID_RELEASE_KEYSTORE_BASE64
  KEYSTORE_PASSWORD
  KEY_ALIAS
  KEY_PASSWORD
''');
}
