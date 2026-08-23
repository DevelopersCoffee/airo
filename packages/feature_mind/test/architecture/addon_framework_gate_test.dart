import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Architecture gate: generic Mind host paths must not embed business template IDs.
void main() {
  final root = Directory.current.path.contains('feature_mind')
      ? Directory.current
      : Directory('packages/feature_mind');

  final forbiddenIds = <String>[
    'insurance_claim_v1',
    'medical_surgery_v1',
    'real_estate_under_construction_v1',
    'study_progress_v1',
    'car_purchase_v1',
    'university_admission_v1',
    'draft-diet-plan',
  ];

  final hostRoots = [
    root.uri.resolve('lib/src/agent_chat/domain/services/'),
    root.uri.resolve('lib/src/agent_chat/data/connectors/'),
  ];

  final violations = <String>[];

  for (final hostRoot in hostRoots) {
    final dir = Directory.fromUri(hostRoot);
    if (!dir.existsSync()) continue;
    for (final entity in dir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll('\\', '/');
      if (path.contains('/addons/')) continue;
      if (path.endsWith('life_track_record_connector.dart')) continue;
      if (path.endsWith('addon_workflow_policy.dart')) continue;
      if (path.endsWith('chat_entity_graph_pending.dart')) continue;
      if (path.endsWith('projected_chat_journey.dart')) continue;
      if (path.endsWith('life_track_fact_extractor.dart')) continue;
      if (path.endsWith('chat_turn_inspector.dart')) continue;
      if (path.endsWith('chat_entity_graph_projector.dart')) continue;
      final content = entity.readAsStringSync();
      for (final id in forbiddenIds) {
        if (content.contains(id)) {
          violations.add('$path contains forbidden id $id');
        }
      }
    }
  }

  test('host services avoid hard-coded business template IDs', () {
    expect(
      violations,
      isEmpty,
      reason: violations.join('\n'),
    );
  });
}
