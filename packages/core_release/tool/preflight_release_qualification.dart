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
  final manifestFile = _requiredFile(repoRoot, options['manifest'], 'manifest');
  final evidenceFile = _optionalFile(repoRoot, options['evidence']);
  final mode = AiroReleaseQualificationMode.parse(
    options['mode']?.single ??
        Platform.environment['QUALIFICATION_MODE'] ??
        'internal',
  );

  final request = AiroReleaseQualificationPreflightRequest(
    mode: mode,
    artifacts: _artifactsFromManifest(_readJson(manifestFile)),
    checks: evidenceFile == null
        ? const []
        : _checksFromEvidence(_readJson(evidenceFile)),
    waivers: evidenceFile == null
        ? const []
        : _waiversFromEvidence(_readJson(evidenceFile)),
  );

  final preflight = const AiroReleaseQualificationPreflightRunner().run(
    request,
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

  if (mode == AiroReleaseQualificationMode.public && !preflight.publicReady) {
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

File _requiredFile(Directory repoRoot, List<String>? option, String name) {
  final value = option?.single;
  if (value == null || value.trim().isEmpty) {
    throw ArgumentError('Missing required --$name path.');
  }
  final file = _resolveUnderRoot(repoRoot, value, name);
  if (!file.existsSync()) {
    throw ArgumentError('$name file does not exist: ${file.path}');
  }
  return file;
}

File? _optionalFile(Directory repoRoot, List<String>? option) {
  final value = option?.single;
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  final file = _resolveUnderRoot(repoRoot, value, 'evidence');
  if (!file.existsSync()) {
    throw ArgumentError('evidence file does not exist: ${file.path}');
  }
  return file;
}

File _resolveUnderRoot(Directory repoRoot, String value, String description) {
  final file = File(value).isAbsolute
      ? File(value)
      : File('${repoRoot.path}/$value');
  final resolvedRoot = repoRoot.resolveSymbolicLinksSync();
  final resolvedParent = file.parent.existsSync()
      ? file.parent.resolveSymbolicLinksSync()
      : file.parent.absolute.path;
  if (!resolvedParent.startsWith(resolvedRoot)) {
    throw ArgumentError('$description path must be inside repository root.');
  }
  return file.absolute;
}

Map<String, Object?> _readJson(File file) {
  final decoded = jsonDecode(file.readAsStringSync());
  if (decoded is Map<String, Object?>) {
    return decoded;
  }
  throw ArgumentError('Expected JSON object in ${file.path}.');
}

List<AiroReleaseArtifactEvidence> _artifactsFromManifest(
  Map<String, Object?> manifest,
) {
  final artifacts = manifest['artifacts'];
  if (artifacts is! List) {
    return const [];
  }
  return [
    for (final item in artifacts)
      if (item is Map)
        AiroReleaseArtifactEvidence(
          profileId: _string(item['profileId']),
          packageId: _string(item['packageId']),
          filename: _string(item['filename']),
          artifactType: _string(item['artifactType']),
          sha256: _string(item['sha256']),
        ),
  ];
}

List<AiroReleaseQualificationCheck> _checksFromEvidence(
  Map<String, Object?> evidence,
) {
  final checks = evidence['checks'];
  if (checks is! List) {
    return const [];
  }
  return [
    for (final item in checks)
      if (item is Map)
        AiroReleaseQualificationCheck(
          profileId: _string(item['profileId']),
          filename: _string(item['filename']),
          deviceClass: _deviceClass(item['deviceClass']),
          evidenceType: _evidenceType(
            item['checkType'] ?? item['evidenceType'],
          ),
          deviceModel: _string(item['deviceModel']),
          osVersion: _string(item['osVersion']),
          result: _result(item['result']),
          notes: _string(item['notes']),
        ),
  ];
}

List<AiroReleaseQualificationWaiver> _waiversFromEvidence(
  Map<String, Object?> evidence,
) {
  final waivers = evidence['waivers'];
  if (waivers is! List) {
    return const [];
  }
  return [
    for (final item in waivers)
      if (item is Map)
        AiroReleaseQualificationWaiver(
          profileId: _string(item['profileId']),
          filename: _string(item['filename']),
          deviceClass: _deviceClass(item['deviceClass']),
          reason: _string(item['reason']),
          approvedBy: _string(item['approvedBy']),
        ),
  ];
}

AiroReleaseDeviceClass _deviceClass(Object? value) {
  final normalized = _normalize(value);
  for (final deviceClass in AiroReleaseDeviceClass.values) {
    if (_normalize(deviceClass.stableId) == normalized) {
      return deviceClass;
    }
  }
  throw ArgumentError.value(value, 'deviceClass', 'Unknown device class.');
}

AiroReleaseQualificationEvidenceType _evidenceType(Object? value) {
  final normalized = _normalize(value);
  for (final type in AiroReleaseQualificationEvidenceType.values) {
    if (_normalize(type.stableId) == normalized) {
      return type;
    }
  }
  throw ArgumentError.value(value, 'evidenceType', 'Unknown evidence type.');
}

AiroReleaseQualificationResult _result(Object? value) {
  final normalized = _normalize(value);
  for (final result in AiroReleaseQualificationResult.values) {
    if (_normalize(result.stableId) == normalized) {
      return result;
    }
  }
  return AiroReleaseQualificationResult.missing;
}

String _normalize(Object? value) {
  return _string(value).toLowerCase().replaceAll('_', '-');
}

String _string(Object? value) => value?.toString().trim() ?? '';

void _writeFile(Directory repoRoot, String path, String contents) {
  final file = File(path).isAbsolute
      ? File(path)
      : File('${repoRoot.path}/$path');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(contents);
}

void _printUsage() {
  stdout.writeln('''
Preflight v2 release qualification evidence.

Usage:
  dart run tool/preflight_release_qualification.dart [options]

Options:
  --repo-root <path>          Workspace root, auto-detected
  --manifest <path>           Release manifest JSON
  --evidence <path>           Qualification evidence JSON
  --mode <mode>               internal or public, defaults to QUALIFICATION_MODE/internal
  --output-json <path>        Write public JSON report
  --output-markdown <path>    Write markdown report
''');
}
