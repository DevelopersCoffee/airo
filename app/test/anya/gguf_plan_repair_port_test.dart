import 'dart:convert';

import 'package:airo_app/anya/gguf_plan_repair_port.dart';
import 'package:core_completion/core_completion.dart';
import 'package:feature_anya/feature_anya.dart';
import 'package:feature_anya_core/feature_anya_core.dart';
import 'package:flutter_test/flutter_test.dart';

const _draft = DietProgram(
  id: 'imported',
  title: 'Clinic plan.pdf',
  source: ProgramSource.imported,
  phases: [
    DietPhase(
      id: 'p1',
      name: 'Phase',
      days: [
        DietDay(
          dayNumber: 7,
          meals: [
            MealSlot(
              type: MealType.breakfast,
              time: '10:00',
              items: [FoodItem(name: 'veg poha', quantityRaw: '1k')],
            ),
          ],
        ),
      ],
    ),
  ],
);

void main() {
  test('GgufPlanRepairPort is available when the completion client is', () {
    final available = GgufPlanRepairPort(FakeCompletionClient());
    final unavailable = GgufPlanRepairPort(
      FakeCompletionClient(available: false),
    );

    expect(available.isAvailable, isTrue);
    expect(unavailable.isAvailable, isFalse);
    expect(unavailable, isA<PlanRepairPort>());
  });

  test('repair forwards draft JSON, JSON-object grammar, and tokens', () async {
    final client = FakeCompletionClient(tokens: const ['{"id":', '"x"}']);
    final port = GgufPlanRepairPort(client, maxTokens: 2048);

    expect(await port.repair(_draft).toList(), ['{"id":', '"x"}']);
    expect(client.lastPrompt, contains(jsonEncode(_draft.toJson())));
    expect(client.lastPrompt, contains('1k'));
    expect(client.lastGrammar, contains('root ::= object'));
    expect(client.lastGrammar, contains('"id"'));
    expect(client.lastGrammar, contains('"title"'));
    expect(client.lastGrammar, contains('"source"'));
    expect(client.lastGrammar, contains('"phases"'));
    expect(client.lastMaxTokens, 2048);
  });
}
