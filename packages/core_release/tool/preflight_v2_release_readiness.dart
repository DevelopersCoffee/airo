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
  final overrides = <String, AiroV2ReleaseGateStatus>{};
  final notes = <String, String>{};

  for (final value in [
    ...?options['gate'],
    ..._splitEnv(Platform.environment['AIRO_V2_RELEASE_GATES']),
  ]) {
    final parsed = _keyValue(value, 'gate');
    overrides[parsed.$1] = AiroV2ReleaseGateStatus.parse(parsed.$2);
  }

  for (final value in [
    ...?options['note'],
    ..._splitEnv(Platform.environment['AIRO_V2_RELEASE_GATE_NOTES']),
  ]) {
    final parsed = _keyValue(value, 'note');
    notes[parsed.$1] = parsed.$2;
  }

  final preflight = const AiroV2ReleaseReadinessPreflightRunner().run(
    overrides: overrides,
    notes: notes,
  );
  final encoded = const JsonEncoder.withIndent(
    '  ',
  ).convert(preflight.toPublicMap());
  stdout.writeln(encoded);

  final outputJson = options['output-json']?.single;
  final outputMarkdown = options['output-markdown']?.single;
  if (outputJson != null) {
    _writeFile(repoRoot, outputJson, encoded);
  }
  if (outputMarkdown != null) {
    _writeFile(repoRoot, outputMarkdown, preflight.toMarkdown());
  }

  if (!preflight.publicReady) {
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
      _addOption(options, arg.substring(2, equals), arg.substring(equals + 1));
      continue;
    }
    final key = arg.substring(2);
    if (index + 1 >= args.length || args[index + 1].startsWith('--')) {
      throw ArgumentError('Missing value for --$key.');
    }
    _addOption(options, key, args[index + 1]);
    index += 1;
  }
  return options;
}

void _addOption(Map<String, List<String>> options, String key, String value) {
  options.putIfAbsent(key, () => <String>[]).add(value);
}

Directory _repoRoot(List<String>? configured) {
  final configuredPath = configured?.single;
  if (configuredPath != null && configuredPath.trim().isNotEmpty) {
    return Directory(configuredPath).absolute;
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

List<String> _splitEnv(String? value) {
  if (value == null || value.trim().isEmpty) {
    return const [];
  }
  return value
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

(String, String) _keyValue(String value, String optionName) {
  final equals = value.indexOf('=');
  if (equals <= 0 || equals == value.length - 1) {
    throw ArgumentError(
      '--$optionName values must use gate_id=value format: $value',
    );
  }
  return (
    value.substring(0, equals).trim(),
    value.substring(equals + 1).trim(),
  );
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
Preflight top-level v2 public release readiness.

Usage:
  dart run tool/preflight_v2_release_readiness.dart [options]

Options:
  --repo-root <path>          Workspace root, auto-detected
  --gate <id=status>          Repeat readiness gate override
  --note <id=text>            Repeat readiness gate note override
  --output-json <path>        Write public JSON report
  --output-markdown <path>    Write markdown report

Gate statuses:
  unknown, blocked, ready, waived, deferred, not_in_scope

Environment alternatives:
  AIRO_V2_RELEASE_GATES="firebase_mobile_clients=ready,android_signing=blocked"
  AIRO_V2_RELEASE_GATE_NOTES="android_signing=waiting for key owner"
''');
}
