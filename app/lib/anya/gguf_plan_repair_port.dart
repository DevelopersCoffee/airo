import 'dart:convert';

import 'package:core_completion/core_completion.dart';
import 'package:feature_anya/feature_anya.dart';
import 'package:feature_anya_core/feature_anya_core.dart';

/// Anya-shell [PlanRepairPort] over a shared [CompletionClient].
///
/// Lives in the flavor, not `feature_anya`, so llama/`core_completion` stay
/// out of the presentation package.
class GgufPlanRepairPort implements PlanRepairPort {
  const GgufPlanRepairPort(this._completion, {this.maxTokens = 2048});

  final CompletionClient _completion;
  final int maxTokens;

  static const _requiredKeys = ['id', 'title', 'source', 'phases'];

  @override
  bool get isAvailable => _completion.isAvailable;

  @override
  Stream<String> repair(DietProgram draft) {
    return _completion.generate(
      prompt: _prompt(draft),
      grammar: jsonObjectGbnf(requiredKeys: _requiredKeys),
      maxTokens: maxTokens,
    );
  }

  String _prompt(DietProgram draft) {
    return 'You repair a nutrition-plan JSON object.\n'
        'Return only one JSON object matching the input schema.\n'
        'Join split food names that belong together.\n'
        'Drop rows whose names are only meal labels '
        '(Breakfast, Lunch, Dinner, Evening, Snack, Early morning, '
        'Mid Morning).\n'
        'Keep every quantityRaw exactly as given. Do not invent calories, '
        'BMI, units, or medical advice.\n'
        'If a quantity looks unclear (for example "1k"), keep it unchanged.\n'
        '\n'
        'DRAFT:\n'
        '${jsonEncode(draft.toJson())}\n';
  }
}
