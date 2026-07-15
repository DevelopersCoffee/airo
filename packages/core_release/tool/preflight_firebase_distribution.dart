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
  final mode = AiroFirebaseDistributionMode.parse(
    _lastOption(options, 'mode') ??
        Platform.environment['FIREBASE_DISTRIBUTION'] ??
        'none',
  );
  final serviceAccountPresent =
      _hasValue(Platform.environment, 'FIREBASE_SERVICE_ACCOUNT_JSON') ||
      _lastOption(options, 'service-account-present') == 'true';
  final profiles = options['profile'] ?? const <String>['tv'];
  final appIds = _targetMap(options['firebase-app-id']);
  final groups = _targetMap(options['tester-groups']);

  final preflight = const AiroFirebaseDistributionPreflightRunner().run(
    AiroFirebaseDistributionPreflightRequest(
      mode: mode,
      serviceAccountPresent: serviceAccountPresent,
      targets:
          AiroFirebaseDistributionPreflightRunner.targetsFromReleaseProfiles(
            matrix: AiroReleaseMatrix.v2Default(),
            profileIds: profiles,
            firebaseAppIds: appIds,
            testerGroups: groups,
          ),
    ),
  );

  final encoded = const JsonEncoder.withIndent(
    '  ',
  ).convert(preflight.toPublicMap());
  stdout.writeln(encoded);

  final outputJson = _lastOption(options, 'output-json');
  final outputMarkdown = _lastOption(options, 'output-markdown');
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

Map<String, String> _targetMap(List<String>? values) {
  final parsed = <String, String>{};
  for (final value in values ?? const <String>[]) {
    final separator = value.indexOf('=');
    if (separator <= 0) {
      throw ArgumentError('Expected profile=value assignment, got: $value');
    }
    parsed[value.substring(0, separator).trim()] = value
        .substring(separator + 1)
        .trim();
  }
  return parsed;
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

void _writeFile(Directory repoRoot, String path, String contents) {
  final file = File(path).isAbsolute
      ? File(path)
      : File('${repoRoot.path}/$path');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(contents);
}

bool _hasValue(Map<String, String> environment, String variable) {
  final value = environment[variable];
  return value != null && value.trim().isNotEmpty;
}

void _printUsage() {
  stdout.writeln('''
Preflight Firebase App Distribution setup without printing credentials.

Usage:
  dart run tool/preflight_firebase_distribution.dart [options]

Options:
  --repo-root <path>             Workspace root, auto-detected by melos.yaml
  --mode <none|upload>           Distribution mode, default: none
  --profile <id>                 Repeat release profile IDs, default: tv
  --firebase-app-id <id=value>   Repeat profile Firebase app IDs
  --tester-groups <id=value>     Repeat profile tester-group lists
  --service-account-present true Override env check for tests/local evidence
  --output-json <path>           Write redacted JSON report
  --output-markdown <path>       Write markdown report
  --help                         Show this help

Required upload inputs:
  FIREBASE_SERVICE_ACCOUNT_JSON
  profile-specific Firebase app IDs
  profile-specific Firebase tester groups
''');
}
