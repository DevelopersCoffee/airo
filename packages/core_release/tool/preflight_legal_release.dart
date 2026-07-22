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
  final profiles = options['profile'];
  final profileIds = profiles == null || profiles.isEmpty
      ? const ['full', 'tv']
      : profiles;
  final privateDependencyConfirmation = AiroPrivateDependencyConfirmation.parse(
    _firstConfigured(
      options['private-dependencies'],
      Platform.environment['AIRO_PRIVATE_DEPENDENCIES'],
      fallback: 'unknown',
    ),
  );
  final provenanceDecision = AiroReleaseProvenanceDecision.parse(
    _firstConfigured(
      options['provenance'],
      Platform.environment['AIRO_RELEASE_PROVENANCE'],
      fallback: 'unknown',
    ),
  );

  final rootLicense = File('${repoRoot.path}/LICENSE');
  final rootLicenseText = rootLicense.existsSync()
      ? rootLicense.readAsStringSync()
      : '';
  final packageLicenses = _packageLicensesForProfiles(
    repoRoot: repoRoot,
    profileIds: profileIds,
    rootLicenseText: rootLicenseText,
  );

  final preflight =
      AiroLegalReleasePreflightRunner(
        matrix: AiroReleaseMatrix.v2Default(),
      ).run(
        AiroLegalReleasePreflightRequest(
          profileIds: profileIds,
          rootLicensePresent: rootLicense.existsSync(),
          rootLicenseText: rootLicenseText,
          licenseReviewPresent: File(
            '${repoRoot.path}/docs/release/V2_LICENSE_REVIEW.md',
          ).existsSync(),
          thirdPartyNoticesPresent: File(
            '${repoRoot.path}/docs/release/V2_THIRD_PARTY_NOTICES.md',
          ).existsSync(),
          packageLicenses: packageLicenses,
          privateDependencyConfirmation: privateDependencyConfirmation,
          provenanceDecision: provenanceDecision,
        ),
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

List<AiroPackageLicenseStatus> _packageLicensesForProfiles({
  required Directory repoRoot,
  required List<String> profileIds,
  required String rootLicenseText,
}) {
  final matrix = AiroReleaseMatrix.v2Default();
  final packagePaths = <String, String>{};
  for (final profileId in profileIds) {
    AiroReleaseProfile profile;
    try {
      profile = matrix.profileById(profileId);
    } on StateError {
      continue;
    }
    final pubspec = File('${repoRoot.path}/${profile.pubspec}');
    if (!pubspec.existsSync()) {
      continue;
    }
    final text = pubspec.readAsStringSync();
    final matches = RegExp(
      r'^\s*path:\s+\.\./packages/([A-Za-z0-9_/-]+)\s*$',
      multiLine: true,
    ).allMatches(text);
    for (final match in matches) {
      final packagePath = 'packages/${match.group(1)!}';
      final packageName = packagePath.split('/').last;
      packagePaths[packageName] = packagePath;
    }
  }

  final statuses = packagePaths.entries.map((entry) {
    final license = File('${repoRoot.path}/${entry.value}/LICENSE');
    final licenseText = license.existsSync() ? license.readAsStringSync() : '';
    return AiroPackageLicenseStatus(
      packageName: entry.key,
      path: entry.value,
      licensePresent: license.existsSync(),
      matchesRootLicense:
          license.existsSync() && licenseText.trim() == rootLicenseText.trim(),
      thirdPartyNoticeCovered: entry.value.contains('/third_party/'),
    );
  }).toList()..sort((a, b) => a.packageName.compareTo(b.packageName));
  return statuses;
}

String _firstConfigured(
  List<String>? option,
  String? environment, {
  required String fallback,
}) {
  final optionValue = option?.single.trim();
  if (optionValue != null && optionValue.isNotEmpty) {
    return optionValue;
  }
  final environmentValue = environment?.trim();
  if (environmentValue != null && environmentValue.isNotEmpty) {
    return environmentValue;
  }
  return fallback;
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
Preflight v2 release legal and provenance readiness.

Usage:
  dart run tool/preflight_legal_release.dart [options]

Options:
  --repo-root <path>                    Workspace root, auto-detected
  --profile <id>                        Repeat release profile IDs
  --private-dependencies <state>        unknown, confirmed_absent, or confirmed_present_approved
  --provenance <decision>               unknown, sha256_only_accepted, or signed_or_slsa_required
  --output-json <path>                  Write JSON report
  --output-markdown <path>              Write markdown report
  --help                                Show this help

Environment fallbacks:
  AIRO_PRIVATE_DEPENDENCIES
  AIRO_RELEASE_PROVENANCE
''');
}
