import 'dart:convert';
import 'dart:io';

import 'package:core_release/core_release.dart';

void main(List<String> args) {
  if (args.contains('--help') || args.contains('-h')) {
    _printUsage();
    return;
  }

  final options = _parseOptions(args);
  final repoRoot = _repoRoot(_lastOption(options, 'repo-root'));
  final googleServicesPath =
      _lastOption(options, 'google-services') ??
      'app/android/app/google-services.json';
  final firebaseOptionsPath =
      _lastOption(options, 'firebase-options') ??
      'app/lib/firebase_options.dart';
  final outputJson = _lastOption(options, 'output-json');
  final outputMarkdown = _lastOption(options, 'output-markdown');

  final expected = _expectedClients(options);
  final preflight = const AiroFirebaseAndroidClientPreflightRunner().run(
    AiroFirebaseAndroidClientPreflightRequest(
      expectedClients: expected,
      googleServicesJson: _readOptionalFile(repoRoot, googleServicesPath),
      firebaseOptionsSource: _readOptionalFile(repoRoot, firebaseOptionsPath),
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

  if (!preflight.ready) {
    exitCode = 1;
  }
}

Map<String, List<String>> _parseOptions(List<String> args) {
  final options = <String, List<String>>{};
  for (var index = 0; index < args.length; index += 1) {
    final arg = args[index];
    if (!arg.startsWith('--')) {
      stderr.writeln('Ignoring positional argument: $arg');
      continue;
    }
    final equals = arg.indexOf('=');
    if (equals > 0) {
      options
          .putIfAbsent(arg.substring(2, equals), () => [])
          .add(arg.substring(equals + 1));
      continue;
    }
    final key = arg.substring(2);
    if (index + 1 >= args.length || args[index + 1].startsWith('--')) {
      throw ArgumentError('Missing value for --$key.');
    }
    options.putIfAbsent(key, () => []).add(args[index + 1]);
    index += 1;
  }
  return options;
}

List<AiroFirebaseAndroidClientExpectation> _expectedClients(
  Map<String, List<String>> options,
) {
  final expectedOptions = options['expected'];
  if (expectedOptions != null && expectedOptions.isNotEmpty) {
    return [for (final value in expectedOptions) _parseExpectedClient(value)];
  }

  final profiles = options['profile'];
  if (profiles != null && profiles.isNotEmpty) {
    return AiroFirebaseAndroidClientPreflightRunner.expectationsFromReleaseProfiles(
      matrix: AiroReleaseMatrix.v2Default(),
      profileIds: profiles,
    );
  }

  return AiroFirebaseAndroidClientPreflightRunner.v2MobileTabletExpectations;
}

AiroFirebaseAndroidClientExpectation _parseExpectedClient(String value) {
  final separator = value.indexOf('=');
  if (separator <= 0 || separator == value.length - 1) {
    throw ArgumentError(
      'Expected --expected package.name=firebaseOptionsName, got: $value',
    );
  }
  return AiroFirebaseAndroidClientExpectation(
    packageName: value.substring(0, separator).trim(),
    firebaseOptionsName: value.substring(separator + 1).trim(),
  );
}

String? _lastOption(Map<String, List<String>> options, String key) {
  final values = options[key];
  if (values == null || values.isEmpty) {
    return null;
  }
  return values.last;
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

String _readOptionalFile(Directory repoRoot, String path) {
  final file = File(path).isAbsolute
      ? File(path)
      : File('${repoRoot.path}/$path');
  if (!file.existsSync()) {
    return '';
  }
  return file.readAsStringSync();
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
Preflight Firebase Android client registration without printing API keys.

Usage:
  dart run tool/preflight_firebase_android_clients.dart [options]

Options:
  --repo-root <path>             Workspace root, auto-detected by melos.yaml
  --google-services <path>       google-services.json path
  --firebase-options <path>      app/lib/firebase_options.dart path
  --profile <id>                 Repeat release profiles to validate
  --expected <package=options>   Repeat explicit package/options pairs
  --output-json <path>           Write redacted JSON report
  --output-markdown <path>       Write markdown report
  --help                         Show this help

Default expected clients:
  io.airo.app=android
''');
}
