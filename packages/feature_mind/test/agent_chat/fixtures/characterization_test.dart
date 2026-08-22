import 'dart:convert';
import 'dart:io';

import 'package:feature_mind/src/agent_chat/data/services/assistant_chat_context_builder.dart';
import 'package:feature_mind/src/agent_chat/data/services/diet_plan_plugin_prompt.dart';
import 'package:feature_mind/src/agent_chat/domain/models/chat_entity_graph.dart';
import 'package:feature_mind/src/agent_chat/domain/models/entity_graph_bridge.dart';
import 'package:feature_mind/src/agent_chat/domain/services/chat_entity_graph_projector.dart';
import 'package:feature_mind/src/agent_chat/domain/services/chat_entity_linker.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _readFixture(String name) {
  final file = File('test/agent_chat/fixtures/characterization/$name.json');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

dynamic _readFixtureRaw(String name) {
  final file = File('test/agent_chat/fixtures/characterization/$name.json');
  return jsonDecode(file.readAsStringSync());
}

void main() {
  const linker = ChatEntityLinker();
  const projector = ChatEntityGraphProjector();

  test('insurance claim graph matches frozen characterization fixture', () {
    final graph = linker.ingest(
      ChatEntityGraph.empty,
      'Niva Bupa reimbursement Claim ID 9001001 via Policybazaar. '
      'All documents received.',
    );
    expect(graph.toJson(), _readFixture('insurance_claim_graph'));
  });

  test('claim plus hospital graph matches frozen characterization fixture', () {
    final graph = linker.ingest(
      ChatEntityGraph.empty,
      'Niva Bupa Claim ID 9001001 after surgery at City Hospital.',
    );
    expect(graph.toJson(), _readFixture('claim_plus_hospital_graph'));

    final journeys = projector.project(graph);
    final fixtureJourneys = (_readFixtureRaw('claim_plus_hospital_journeys') as List)
        .cast<Map<String, dynamic>>();
    expect(
      journeys
          .map(
            (journey) => {
              'template_id': journey.templateId,
              'facts': journey.facts,
              'is_offerable': journey.isOfferable,
              'title': journey.title,
            },
          )
          .toList(growable: false),
      fixtureJourneys,
    );
  });

  test('property purchase graph matches frozen characterization fixture', () {
    final graph = linker.ingest(
      ChatEntityGraph.empty,
      'buying Tower B floor 14 from Prestige, RERA P52100012345',
    );
    expect(graph.toJson(), _readFixture('property_purchase_graph'));

    final journey = projector.project(graph).single;
    final fixture = _readFixture('property_purchase_journey');
    expect(journey.templateId, fixture['template_id']);
    expect(journey.facts, fixture['facts']);
    expect(journey.isOfferable, fixture['is_offerable']);
  });

  test('diet constraints match frozen characterization fixture', () {
    final fixture = _readFixture('diet_constraints');
    final history = [
      const AssistantChatContextMessage(
        text: 'Make me a 7 day diet plan',
        isUser: true,
      ),
      const AssistantChatContextMessage(text: 'Day 1 menu', isUser: false),
      const AssistantChatContextMessage(
        text: 'i want some indian menu only',
        isUser: true,
      ),
      const AssistantChatContextMessage(text: 'Day 1 indian', isUser: false),
    ];
    const current = 'veg only';

    expect(
      DietPlanPluginPrompt.userConstraintLines(
        currentPrompt: current,
        history: history,
      ),
      fixture['constraints'],
    );

    final prompt = DietPlanPluginPrompt.modelUserPrompt(
      currentPrompt: current,
      history: history,
    );
    final checks = fixture['prompt_checks'] as Map<String, dynamic>;
    expect(prompt.contains('Duration: 7 days'), checks['duration_7_days']);
    expect(prompt.contains('indian menu only'), checks['indian_menu']);
    expect(prompt.contains('veg only'), checks['veg_only']);
  });

  test('ChatEntityGraph bridge round-trips neutral EntityGraph JSON', () {
    final graph = linker.ingest(
      ChatEntityGraph.empty,
      'Niva Bupa Claim ID 9001001',
    );
    final neutral = graph.toEntityGraph();
    final restored = ChatEntityGraphBridge.fromEntityGraph(neutral);
    expect(restored.toJson(), graph.toJson());
    expect(neutral.toJson(), graph.toEntityGraph().toJson());
  });
}
