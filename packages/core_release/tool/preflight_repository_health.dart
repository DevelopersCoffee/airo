import 'dart:convert';
import 'dart:io';

import 'package:core_release/core_release.dart';

void main(List<String> args) async {
  if (args.contains('--help') || args.contains('-h')) {
    _printUsage();
    return;
  }

  final options = _parseOptions(args);
  final repoRoot = _repoRoot(options['repo-root']);
  final readmeText = _readIfExists('${repoRoot.path}/README.md');
  final labels = <String>{...?options['label'], ..._labelsFromEnvironment()};
  var labelsAvailable = labels.isNotEmpty;
  if (labels.isEmpty && !_truthy(options['skip-gh-labels']?.single)) {
    final ghLabels = await _labelsFromGh(repoRoot);
    labels.addAll(ghLabels);
    labelsAvailable = ghLabels.isNotEmpty;
  }

  final request = AiroRepositoryHealthPreflightRequest(
    requiredFiles: _requiredFiles(repoRoot),
    issueTemplates: _issueTemplates(repoRoot),
    readmeTextChecks: AiroRepositoryHealthPreflightRunner.requiredReadmeText
        .map(
          (needle) => readmeText.contains(needle)
              ? 'present:$needle'
              : 'missing:$needle',
        ),
    labels: labels,
    labelsAvailable: labelsAvailable,
    codeownersPresent:
        File('${repoRoot.path}/CODEOWNERS').existsSync() ||
        File('${repoRoot.path}/.github/CODEOWNERS').existsSync(),
    fundingPresent: File('${repoRoot.path}/.github/FUNDING.yml').existsSync(),
    discussionsDecision: AiroRepositoryDecision.parse(
      _firstConfigured(
        options['discussions'],
        Platform.environment['AIRO_REPO_DISCUSSIONS'],
        fallback: 'unknown',
      ),
    ),
    codeownersDecision: AiroRepositoryDecision.parse(
      _firstConfigured(
        options['codeowners'],
        Platform.environment['AIRO_REPO_CODEOWNERS'],
        fallback: 'unknown',
      ),
    ),
    fundingDecision: AiroRepositoryDecision.parse(
      _firstConfigured(
        options['funding'],
        Platform.environment['AIRO_REPO_FUNDING'],
        fallback: 'unknown',
      ),
    ),
  );

  final preflight = const AiroRepositoryHealthPreflightRunner().run(request);
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
    if (key == 'skip-gh-labels') {
      _addOption(options, key, 'true');
      continue;
    }
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

List<AiroRepositoryFileStatus> _requiredFiles(Directory repoRoot) {
  const paths = [
    'README.md',
    'SECURITY.md',
    'CONTRIBUTING.md',
    'CODE_OF_CONDUCT.md',
    '.github/PULL_REQUEST_TEMPLATE.md',
    'docs/release/RELEASE_CHECKLIST.md',
    'docs/release/V2_PUBLISHING_HUMAN_SETUP.md',
    'docs/release/V2_HUMAN_IN_LOOP_BLOCKERS.md',
    'docs/release/REPOSITORY_HEALTH_STATUS.md',
    'docs/release/STORE_COMPLIANCE.md',
    'docs/release/V2_RELEASE_ORCHESTRATOR.md',
  ];
  return [
    for (final path in paths)
      AiroRepositoryFileStatus(
        path: path,
        present: File('${repoRoot.path}/$path').existsSync(),
      ),
  ];
}

List<AiroRepositoryFileStatus> _issueTemplates(Directory repoRoot) {
  const paths = [
    '.github/ISSUE_TEMPLATE/user_bug_report.md',
    '.github/ISSUE_TEMPLATE/feature_request.yml',
    '.github/ISSUE_TEMPLATE/question.yml',
    '.github/ISSUE_TEMPLATE/agent_task.md',
  ];
  return [
    for (final path in paths)
      AiroRepositoryFileStatus(
        path: path,
        present: File('${repoRoot.path}/$path').existsSync(),
      ),
  ];
}

List<String> _labelsFromEnvironment() {
  final raw = Platform.environment['AIRO_REPO_LABELS']?.trim();
  if (raw == null || raw.isEmpty) {
    return const [];
  }
  return raw
      .split(',')
      .map((label) => label.trim())
      .where((label) => label.isNotEmpty)
      .toList();
}

Future<List<String>> _labelsFromGh(Directory repoRoot) async {
  try {
    final result = await Process.run('gh', [
      'label',
      'list',
      '--limit',
      '200',
      '--json',
      'name',
    ], workingDirectory: repoRoot.path);
    if (result.exitCode != 0) {
      return const [];
    }
    final decoded = jsonDecode(result.stdout as String);
    if (decoded is! List) {
      return const [];
    }
    return [
      for (final item in decoded)
        if (item is Map && item['name'] is String) item['name'] as String,
    ];
  } on Object {
    return const [];
  }
}

String _readIfExists(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    return '';
  }
  return file.readAsStringSync();
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

bool _truthy(String? value) {
  if (value == null) {
    return false;
  }
  final normalized = value.trim().toLowerCase();
  return normalized == '1' || normalized == 'true' || normalized == 'yes';
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
Preflight public repository health for v2 release readiness.

Usage:
  dart run tool/preflight_repository_health.dart [options]

Options:
  --repo-root <path>          Workspace root, auto-detected
  --label <name>              Repeat repository labels, defaults to gh label list
  --skip-gh-labels            Do not call gh for labels
  --discussions <decision>    unknown, enabled, or not_required
  --codeowners <decision>     unknown, present, or not_required
  --funding <decision>        unknown, present, or intentionally_absent
  --output-json <path>        Write JSON report
  --output-markdown <path>    Write markdown report
  --help                      Show this help

Environment fallbacks:
  AIRO_REPO_LABELS
  AIRO_REPO_DISCUSSIONS
  AIRO_REPO_CODEOWNERS
  AIRO_REPO_FUNDING
''');
}
