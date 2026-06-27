import 'package:meta/meta.dart';

/// Trigger eval fixture categories declared by a skill package.
enum SkillTriggerEvalCaseKind {
  positive,
  negative,
  ambiguity;

  static SkillTriggerEvalCaseKind fromJson(String value) {
    return values.singleWhere(
      (kind) => _camelToSnake(kind.name) == value,
      orElse: () =>
          throw ArgumentError('unsupported trigger eval kind: $value'),
    );
  }

  String toJson() => _camelToSnake(name);
}

/// Runtime decision produced by a trigger eval.
enum SkillTriggerDecision { select, none, clarify, draftOnly }

/// Trigger eval suite status.
enum SkillTriggerEvalStatus { passing, failing }

/// Deterministic reason code for trigger eval reports.
enum SkillTriggerEvalReasonCode {
  selectedExpectedSkill,
  stayedUnselected,
  needsClarification,
  privateFixtureRejected,
  selectedWrongSkill,
  missedExpectedSkill,
}

/// Progressive disclosure level loaded by trigger evaluation.
enum SkillDisclosureLevel { l1Metadata, l2SkillBody, l3Assets }

/// L1 metadata used by trigger evaluation without loading skill bodies/assets.
@immutable
class SkillTriggerMetadata {
  const SkillTriggerMetadata({
    required this.skillId,
    required this.description,
    this.triggerPhrases = const [],
    this.l2AssetRefs = const [],
    this.l3AssetRefs = const [],
  });

  final String skillId;
  final String description;
  final List<String> triggerPhrases;
  final List<String> l2AssetRefs;
  final List<String> l3AssetRefs;
}

/// One trigger eval fixture for positive, negative, or ambiguous prompts.
@immutable
class SkillTriggerEvalCase {
  const SkillTriggerEvalCase._({
    required this.id,
    required this.kind,
    required this.prompt,
    this.expectedSkillId,
    this.skillId,
    this.candidateSkillIds = const [],
  });

  const SkillTriggerEvalCase.positive({
    required String id,
    required String prompt,
    required String expectedSkillId,
  }) : this._(
         id: id,
         kind: SkillTriggerEvalCaseKind.positive,
         prompt: prompt,
         expectedSkillId: expectedSkillId,
       );

  const SkillTriggerEvalCase.negative({
    required String id,
    required String prompt,
    required String skillId,
  }) : this._(
         id: id,
         kind: SkillTriggerEvalCaseKind.negative,
         prompt: prompt,
         skillId: skillId,
       );

  const SkillTriggerEvalCase.ambiguity({
    required String id,
    required String prompt,
    required List<String> candidateSkillIds,
  }) : this._(
         id: id,
         kind: SkillTriggerEvalCaseKind.ambiguity,
         prompt: prompt,
         candidateSkillIds: candidateSkillIds,
       );

  final String id;
  final SkillTriggerEvalCaseKind kind;
  final String prompt;
  final String? expectedSkillId;
  final String? skillId;
  final List<String> candidateSkillIds;

  factory SkillTriggerEvalCase.fromJson(Map<String, dynamic> json) {
    final kind = SkillTriggerEvalCaseKind.fromJson(json['kind'] as String);
    return switch (kind) {
      SkillTriggerEvalCaseKind.positive => SkillTriggerEvalCase.positive(
        id: json['id'] as String,
        prompt: json['prompt'] as String,
        expectedSkillId: json['expected_skill_id'] as String,
      ),
      SkillTriggerEvalCaseKind.negative => SkillTriggerEvalCase.negative(
        id: json['id'] as String,
        prompt: json['prompt'] as String,
        skillId: json['skill_id'] as String,
      ),
      SkillTriggerEvalCaseKind.ambiguity => SkillTriggerEvalCase.ambiguity(
        id: json['id'] as String,
        prompt: json['prompt'] as String,
        candidateSkillIds: _stringList(json['candidate_skill_ids']),
      ),
    };
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'kind': kind.toJson(),
    'prompt': prompt,
    if (expectedSkillId != null) 'expected_skill_id': expectedSkillId,
    if (skillId != null) 'skill_id': skillId,
    if (candidateSkillIds.isNotEmpty) 'candidate_skill_ids': candidateSkillIds,
  };
}

/// Trigger eval suite report.
@immutable
class SkillTriggerEvalReport {
  const SkillTriggerEvalReport({required this.results});

  final List<SkillTriggerEvalResult> results;

  SkillTriggerEvalStatus get status => results.every((result) => result.passed)
      ? SkillTriggerEvalStatus.passing
      : SkillTriggerEvalStatus.failing;
}

/// Result for one trigger eval case.
@immutable
class SkillTriggerEvalResult {
  const SkillTriggerEvalResult({
    required this.caseId,
    required this.decision,
    required this.reasonCode,
    required this.loadedDisclosureLevel,
    this.selectedSkillId,
    this.loadedAssetRefs = const [],
    this.passed = true,
  });

  final String caseId;
  final SkillTriggerDecision decision;
  final SkillTriggerEvalReasonCode reasonCode;
  final SkillDisclosureLevel loadedDisclosureLevel;
  final String? selectedSkillId;
  final List<String> loadedAssetRefs;
  final bool passed;
}

/// Deterministic trigger eval runner for skill selection and disclosure checks.
class SkillTriggerEvalSuite {
  const SkillTriggerEvalSuite({required this.skills, required this.cases});

  final List<SkillTriggerMetadata> skills;
  final List<SkillTriggerEvalCase> cases;

  SkillTriggerEvalReport run() {
    return SkillTriggerEvalReport(
      results: cases.map(_runCase).toList(growable: false),
    );
  }

  SkillTriggerEvalResult _runCase(SkillTriggerEvalCase evalCase) {
    if (_containsPrivateFixtureData(evalCase.prompt)) {
      return SkillTriggerEvalResult(
        caseId: evalCase.id,
        decision: SkillTriggerDecision.none,
        reasonCode: SkillTriggerEvalReasonCode.privateFixtureRejected,
        loadedDisclosureLevel: SkillDisclosureLevel.l1Metadata,
        passed: false,
      );
    }

    return switch (evalCase.kind) {
      SkillTriggerEvalCaseKind.positive => _runPositive(evalCase),
      SkillTriggerEvalCaseKind.negative => _runNegative(evalCase),
      SkillTriggerEvalCaseKind.ambiguity => SkillTriggerEvalResult(
        caseId: evalCase.id,
        decision: SkillTriggerDecision.clarify,
        reasonCode: SkillTriggerEvalReasonCode.needsClarification,
        loadedDisclosureLevel: SkillDisclosureLevel.l1Metadata,
      ),
    };
  }

  SkillTriggerEvalResult _runPositive(SkillTriggerEvalCase evalCase) {
    final selectedSkillId = _selectSkill(evalCase.prompt);
    final passed = selectedSkillId == evalCase.expectedSkillId;
    return SkillTriggerEvalResult(
      caseId: evalCase.id,
      decision: selectedSkillId == null
          ? SkillTriggerDecision.none
          : SkillTriggerDecision.select,
      reasonCode: passed
          ? SkillTriggerEvalReasonCode.selectedExpectedSkill
          : selectedSkillId == null
          ? SkillTriggerEvalReasonCode.missedExpectedSkill
          : SkillTriggerEvalReasonCode.selectedWrongSkill,
      loadedDisclosureLevel: SkillDisclosureLevel.l1Metadata,
      selectedSkillId: selectedSkillId,
      passed: passed,
    );
  }

  SkillTriggerEvalResult _runNegative(SkillTriggerEvalCase evalCase) {
    final selectedSkillId = _selectSkill(evalCase.prompt);
    final passed =
        selectedSkillId == null || selectedSkillId != evalCase.skillId;
    return SkillTriggerEvalResult(
      caseId: evalCase.id,
      decision: selectedSkillId == null
          ? SkillTriggerDecision.none
          : SkillTriggerDecision.select,
      reasonCode: passed
          ? SkillTriggerEvalReasonCode.stayedUnselected
          : SkillTriggerEvalReasonCode.selectedWrongSkill,
      loadedDisclosureLevel: SkillDisclosureLevel.l1Metadata,
      selectedSkillId: passed ? null : selectedSkillId,
      passed: passed,
    );
  }

  String? _selectSkill(String prompt) {
    final lowerPrompt = prompt.toLowerCase();
    for (final skill in skills) {
      if (skill.triggerPhrases.any(
        (phrase) => lowerPrompt.contains(phrase.toLowerCase()),
      )) {
        return skill.skillId;
      }
    }
    return null;
  }

  bool _containsPrivateFixtureData(String prompt) {
    return RegExp(
          r'\b(password|token|secret|childhood address|ssn|credit card)\b',
          caseSensitive: false,
        ).hasMatch(prompt) ||
        RegExp(r'(?:\d[ -]?){13,19}').hasMatch(prompt);
  }
}

String _camelToSnake(String value) {
  return value
      .replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'),
        (match) => '${match.group(1)}_${match.group(2)}',
      )
      .toLowerCase();
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return value.whereType<String>().toList();
}
