import 'dart:convert';
import 'dart:io';

import 'package:feature_mind/src/agent_chat/data/services/assistant_chat_context_builder.dart';
import 'package:feature_mind/src/agent_chat/data/services/diet_plan_plugin_prompt.dart';
import 'package:feature_mind/src/agent_chat/domain/models/chat_entity_graph.dart';
import 'package:feature_mind/src/agent_chat/domain/services/chat_entity_graph_projector.dart';
import 'package:feature_mind/src/agent_chat/domain/services/chat_entity_linker.dart';
import 'package:flutter_test/flutter_test.dart';

/// Run with GENERATE_FIXTURES=1 to refresh characterization JSON.
void main() {
  test('generate characterization fixtures', () {
    if (Platform.environment['GENERATE_FIXTURES'] != '1') return;

    const linker = ChatEntityLinker();
    const projector = ChatEntityGraphProjector();
    final outDir = Directory('test/agent_chat/fixtures/characterization');
    outDir.createSync(recursive: true);

    void write(String name, Object data) {
      File('${outDir.path}/$name.json').writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(data),
      );
    }

    final insurance = linker.ingest(
      ChatEntityGraph.empty,
      'Niva Bupa reimbursement Claim ID 9001001 via Policybazaar. '
      'All documents received.',
    );
    write('insurance_claim_graph', insurance.toJson());

    final dual = linker.ingest(
      ChatEntityGraph.empty,
      'Niva Bupa Claim ID 9001001 after surgery at City Hospital.',
    );
    write('claim_plus_hospital_graph', dual.toJson());
    write(
      'claim_plus_hospital_journeys',
      projector
          .project(dual)
          .map(
            (journey) => {
              'template_id': journey.templateId,
              'facts': journey.facts,
              'is_offerable': journey.isOfferable,
              'title': journey.title,
            },
          )
          .toList(growable: false),
    );

    final property = linker.ingest(
      ChatEntityGraph.empty,
      'buying Tower B floor 14 from Prestige, RERA P52100012345',
    );
    write('property_purchase_graph', property.toJson());
    final propertyJourney = projector.project(property).single;
    write(
      'property_purchase_journey',
      {
        'template_id': propertyJourney.templateId,
        'facts': propertyJourney.facts,
        'is_offerable': propertyJourney.isOfferable,
      },
    );

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
    write(
      'diet_constraints',
      {
        'constraints': DietPlanPluginPrompt.userConstraintLines(
          currentPrompt: current,
          history: history,
        ),
        'prompt_checks': {
          'duration_7_days': DietPlanPluginPrompt.modelUserPrompt(
            currentPrompt: current,
            history: history,
          ).contains('Duration: 7 days'),
          'indian_menu': DietPlanPluginPrompt.modelUserPrompt(
            currentPrompt: current,
            history: history,
          ).contains('indian menu only'),
          'veg_only': DietPlanPluginPrompt.modelUserPrompt(
            currentPrompt: current,
            history: history,
          ).contains('veg only'),
        },
      },
    );
  });
}
