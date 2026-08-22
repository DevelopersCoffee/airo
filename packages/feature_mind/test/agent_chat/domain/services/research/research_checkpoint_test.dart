import 'dart:io';

import 'package:feature_mind/src/agent_chat/domain/models/research_event.dart';
import 'package:feature_mind/src/agent_chat/domain/models/research_request.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/research_checkpoint.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'checkpoint record preserves mode and privacy policy across restart',
    () {
      const checkpoint = ResearchCheckpoint(
        jobId: 'job-1',
        question: 'Pixel 9 offline LLM',
        state: ResearchPhase.paused,
        pausedFrom: ResearchPhase.analyzing,
        searchesUsed: 2,
        iterationsUsed: 1,
        completedNodeIds: ['n1', 'n2'],
        mode: ResearchMode.quick,
        policy: SearchPolicy.privacyFirst,
      );

      final restored = ResearchCheckpoint.fromRecord(checkpoint.toRecord());
      expect(restored, checkpoint);
      expect(
        checkpoint.toRecord(),
        'v2\u{1f}job-1\u{1f}Pixel 9 offline LLM\u{1f}paused\u{1f}analyzing'
        '\u{1f}2\u{1f}1\u{1f}n1,n2\u{1f}quick\u{1f}privacy_first',
      );
      expect(restored.privacy, PrivacyProfile.private);
    },
  );

  test('legacy v1 checkpoint fails closed as quick local-only research', () {
    final restored = ResearchCheckpoint.fromRecord(
      'v1\u{1f}job-1\u{1f}Legacy\u{1f}paused\u{1f}searching'
      '\u{1f}2\u{1f}1\u{1f}n1',
    );

    expect(restored.mode, ResearchMode.quick);
    expect(restored.policy, SearchPolicy.localOnly);
    expect(restored.privacy, PrivacyProfile.private);
  });

  test('Dart decoder matches shared valid and corrupt fixtures', () {
    final lines = File('../../test_fixtures/research_checkpoint_records.txt')
        .readAsLinesSync()
        .where((line) => line.isNotEmpty && !line.startsWith('#'));

    for (final line in lines) {
      final parts = line.split('|');
      final kind = parts[0];
      final name = parts[1];
      final record = parts.sublist(2).join('|').replaceAll(r'\x1f', '\u{1f}');
      if (kind == 'valid') {
        expect(
          () => ResearchCheckpoint.fromRecord(record),
          returnsNormally,
          reason: name,
        );
      } else {
        expect(
          () => ResearchCheckpoint.fromRecord(record),
          throwsFormatException,
          reason: name,
        );
      }
    }
  });
}
