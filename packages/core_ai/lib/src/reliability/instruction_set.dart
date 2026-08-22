import 'package:meta/meta.dart';

import 'prompt_reliability.dart';

/// Layered instructions, highest authority first. Mirror of
/// `airo_mind_reliability::InstructionLayer`.
enum InstructionLayer { system, task, user, context, output }

/// One instruction at a known layer.
@immutable
class Instruction {
  const Instruction({required this.layer, required this.text});

  final InstructionLayer layer;
  final String text;
}

enum InstructionIssueKind {
  conflict,
  missing,
  ambiguous,
  duplicate,
  unsatisfiable,
}

@immutable
class InstructionIssue {
  const InstructionIssue({
    required this.kind,
    required this.defect,
    required this.left,
    required this.right,
  });

  final InstructionIssueKind kind;
  final PromptDefect defect;
  final int left;
  final int right;
}

/// Machine-readable instruction IR. Analyze compiled system + task + user
/// prompts; do not treat retrieved context as instructions.
@immutable
class InstructionSet {
  const InstructionSet({this.items = const []});

  final List<Instruction> items;

  factory InstructionSet.fromLayers({
    String system = '',
    String task = '',
    String user = '',
    String context = '',
    String output = '',
  }) {
    final items = <Instruction>[
      if (system.trim().isNotEmpty)
        Instruction(layer: InstructionLayer.system, text: system),
      if (task.trim().isNotEmpty)
        Instruction(layer: InstructionLayer.task, text: task),
      if (user.trim().isNotEmpty)
        Instruction(layer: InstructionLayer.user, text: user),
      if (context.trim().isNotEmpty)
        Instruction(layer: InstructionLayer.context, text: context),
      if (output.trim().isNotEmpty)
        Instruction(layer: InstructionLayer.output, text: output),
    ];
    return InstructionSet(items: items);
  }

  String get userText {
    for (final item in items) {
      if (item.layer == InstructionLayer.user) return item.text;
    }
    return '';
  }

  /// Full analysis. Blocking kinds still belong to the user-turn gate;
  /// [compiledWarnings] is what live chat/skill paths attach.
  List<InstructionIssue> analyze({required bool hasAcceptanceCriteria}) {
    final issues = <InstructionIssue>[];
    _collectDuplicates(issues);
    _collectPolarityIssues(issues);
    if (userText.isEmpty) {
      issues.add(
        const InstructionIssue(
          kind: InstructionIssueKind.missing,
          defect: PromptDefect.spec002UnderspecifiedConstraints,
          left: 0,
          right: 0,
        ),
      );
    }
    if (_isAmbiguous(userText)) {
      issues.add(
        const InstructionIssue(
          kind: InstructionIssueKind.ambiguous,
          defect: PromptDefect.spec001AmbiguousInstruction,
          left: 0,
          right: 0,
        ),
      );
    }
    if (!hasAcceptanceCriteria && _needsCriteria(userText)) {
      issues.add(
        const InstructionIssue(
          kind: InstructionIssueKind.missing,
          defect: PromptDefect.spec002UnderspecifiedConstraints,
          left: 0,
          right: 0,
        ),
      );
    }
    return issues;
  }

  /// Cross-layer / compiled-system issues. Never used to flip Allow → AskUser.
  List<InstructionIssue> compiledWarnings({
    required bool hasAcceptanceCriteria,
  }) {
    return analyze(
      hasAcceptanceCriteria: hasAcceptanceCriteria,
    ).where(_isCompiledWarning).toList(growable: false);
  }

  bool _isCompiledWarning(InstructionIssue issue) {
    switch (issue.kind) {
      case InstructionIssueKind.conflict:
      case InstructionIssueKind.duplicate:
        return true;
      case InstructionIssueKind.unsatisfiable:
        return !_isUserOnly(issue);
      case InstructionIssueKind.missing:
      case InstructionIssueKind.ambiguous:
        return false;
    }
  }

  bool _isUserOnly(InstructionIssue issue) {
    if (items.isEmpty) return true;
    final left = items[issue.left.clamp(0, items.length - 1)].layer;
    final right = items[issue.right.clamp(0, items.length - 1)].layer;
    return left == InstructionLayer.user && right == InstructionLayer.user;
  }

  void _collectDuplicates(List<InstructionIssue> issues) {
    for (var i = 0; i < items.length; i++) {
      for (var j = i + 1; j < items.length; j++) {
        if (items[i].text.trim().isEmpty) continue;
        if (_normalize(items[i].text) == _normalize(items[j].text)) {
          issues.add(
            InstructionIssue(
              kind: InstructionIssueKind.duplicate,
              defect: PromptDefect.spec003ConflictingInstructions,
              left: i,
              right: j,
            ),
          );
        }
      }
    }
  }

  void _collectPolarityIssues(List<InstructionIssue> issues) {
    _collectAxis(issues, _brevityPolarity);
    _collectAxis(issues, _formatPolarity);
    for (var idx = 0; idx < items.length; idx++) {
      final text = items[idx].text;
      if (_bothPoles(_brevityMarkers(text)) ||
          _bothPoles(_formatMarkers(text))) {
        issues.add(
          InstructionIssue(
            kind: InstructionIssueKind.unsatisfiable,
            defect: PromptDefect.spec003ConflictingInstructions,
            left: idx,
            right: idx,
          ),
        );
      }
    }
  }

  void _collectAxis(
    List<InstructionIssue> issues,
    bool? Function(String text) polarity,
  ) {
    final seen = <(int, bool, InstructionLayer)>[];
    for (var idx = 0; idx < items.length; idx++) {
      final pole = polarity(items[idx].text);
      if (pole == null) continue;
      for (final (otherIdx, otherPole, otherLayer) in seen) {
        if (pole != otherPole) {
          final sameLayer = items[idx].layer == otherLayer;
          issues.add(
            InstructionIssue(
              kind: sameLayer
                  ? InstructionIssueKind.unsatisfiable
                  : InstructionIssueKind.conflict,
              defect: PromptDefect.spec003ConflictingInstructions,
              left: otherIdx,
              right: idx,
            ),
          );
        }
      }
      seen.add((idx, pole, items[idx].layer));
    }
  }
}

String _normalize(String text) {
  return text
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .join(' ');
}

bool _bothPoles((bool, bool) markers) => markers.$1 && markers.$2;

(bool, bool) _brevityMarkers(String text) {
  final t = text.toLowerCase();
  return (
    t.contains('be brief') ||
        t.contains('concise') ||
        t.contains('one sentence') ||
        t.contains('short answer'),
    t.contains('extensive detail') ||
        t.contains('be detailed') ||
        t.contains('comprehensive') ||
        t.contains('as much detail'),
  );
}

(bool, bool) _formatMarkers(String text) {
  final t = text.toLowerCase();
  return (
    t.contains('json only') ||
        t.contains('respond in json') ||
        t.contains('output json') ||
        t.contains('return json'),
    t.contains('markdown only') ||
        t.contains('respond in markdown') ||
        t.contains('output markdown') ||
        t.contains('explain this normally') ||
        t.contains('explain normally') ||
        t.contains('in prose'),
  );
}

bool? _brevityPolarity(String text) {
  final markers = _brevityMarkers(text);
  if (markers.$1 && !markers.$2) return true;
  if (!markers.$1 && markers.$2) return false;
  return null;
}

bool? _formatPolarity(String text) {
  final markers = _formatMarkers(text);
  if (markers.$1 && !markers.$2) return true;
  if (!markers.$1 && markers.$2) return false;
  return null;
}

bool _isAmbiguous(String user) {
  const ambiguous = {
    'make it better',
    'make this better',
    'make that better',
    'make my code better',
    'improve it',
    'improve this',
    'improve that',
    'improve my code',
    'improve the code',
    'fix it',
    'fix this',
    'fix that',
    'optimize it',
    'optimize this',
    'optimize that',
    'do it',
    'do that',
    'book that one',
  };
  return ambiguous.contains(_normalize(user));
}

bool _needsCriteria(String user) {
  const extra = {
    'generate test cases',
    'generate tests',
    'write tests',
    'write a summary',
    'summarize this',
  };
  return _isAmbiguous(user) || extra.contains(_normalize(user));
}
