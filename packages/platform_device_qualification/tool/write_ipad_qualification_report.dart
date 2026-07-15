import 'dart:convert';
import 'dart:io';

import 'package:platform_device_qualification/qualification_reports.dart';

void main(List<String> args) {
  if (args.contains('--help') || args.contains('-h')) {
    _printUsage();
    return;
  }

  final options = _parseOptions(args);
  final repoRoot = _repoRoot(_lastOption(options, 'repo-root'));
  final reportId =
      _lastOption(options, 'report-id') ?? 'manual-ipad-air-qualification';
  final campaignId =
      _lastOption(options, 'campaign-id') ?? 'issue-716-ipad-air';
  final deviceName = _lastOption(options, 'device') ?? 'iPad Air';
  final appProfile =
      _lastOption(options, 'app-profile') ?? 'Airo TV qualification';
  final playlistProfile =
      _lastOption(options, 'playlist-profile') ?? 'iptv-org-public';
  final phases = _parsePhaseStatuses(options['phase']);
  final defectCounts = _parseIntMap(options['defects']);
  final notes = _parseStringMap(options['note']);

  final report = const IpadQualificationReportBuilder().build(
    reportId: reportId,
    campaignId: campaignId,
    deviceName: deviceName,
    appProfile: appProfile,
    playlistProfile: playlistProfile,
    phaseStatuses: phases,
    defectCounts: defectCounts,
    notes: notes,
  );

  final encoded = const JsonEncoder.withIndent(
    '  ',
  ).convert(report.toPublicMap());
  stdout.writeln(encoded);

  final outputJson = _lastOption(options, 'output-json');
  final outputMarkdown = _lastOption(options, 'output-markdown');
  if (outputJson != null) {
    _writeFile(repoRoot, outputJson, encoded);
  }
  if (outputMarkdown != null) {
    _writeFile(repoRoot, outputMarkdown, report.toMarkdown());
  }

  if (!report.completeForIssueEvidence) {
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

Map<String, IpadQualificationPhaseStatus> _parsePhaseStatuses(
  List<String>? values,
) {
  final parsed = <String, IpadQualificationPhaseStatus>{};
  for (final value in values ?? const <String>[]) {
    final entry = _splitAssignment(value, option: 'phase');
    parsed[entry.key] = IpadQualificationPhaseStatus.parse(entry.value);
  }
  return parsed;
}

Map<String, int> _parseIntMap(List<String>? values) {
  final parsed = <String, int>{};
  for (final value in values ?? const <String>[]) {
    final entry = _splitAssignment(value, option: 'defects');
    parsed[entry.key] = int.parse(entry.value);
  }
  return parsed;
}

Map<String, String> _parseStringMap(List<String>? values) {
  final parsed = <String, String>{};
  for (final value in values ?? const <String>[]) {
    final entry = _splitAssignment(value, option: 'note');
    parsed[entry.key] = entry.value;
  }
  return parsed;
}

MapEntry<String, String> _splitAssignment(
  String value, {
  required String option,
}) {
  final separator = value.indexOf('=');
  if (separator <= 0 || separator == value.length - 1) {
    throw ArgumentError('Expected --$option phase_id=value, got: $value');
  }
  return MapEntry(
    value.substring(0, separator),
    value.substring(separator + 1),
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
  final phaseHelp = kDefaultIpadQualificationPhases
      .map((phase) => '  ${phase.id.padRight(34)} ${phase.title}')
      .join('\n');

  stdout.writeln('''
Write an iPad Air qualification report from explicit phase results.

Usage:
  dart run tool/write_ipad_qualification_report.dart [options]

Options:
  --report-id <id>              Report identifier
  --campaign-id <id>            Campaign identifier, default: issue-716-ipad-air
  --device <name>               Device name, default: iPad Air
  --app-profile <name>          App profile label
  --playlist-profile <name>     Playlist profile label
  --phase <id=status>           Repeat for each phase; status: passed, failed, waived, missing
  --defects <id=count>          Optional defect count per phase
  --note <id=text>              Optional note per phase
  --output-json <path>          Write JSON report
  --output-markdown <path>      Write markdown report
  --help                        Show this help

Required phase ids:
$phaseHelp
''');
}
