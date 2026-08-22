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

  test('legacy v1 checkpoint decodes as deep Balanced research', () {
    final restored = ResearchCheckpoint.fromRecord(
      'v1\u{1f}job-1\u{1f}Legacy\u{1f}paused\u{1f}searching'
      '\u{1f}2\u{1f}1\u{1f}n1',
    );

    expect(restored.mode, ResearchMode.deep);
    expect(restored.policy, SearchPolicy.balanced);
    expect(restored.privacy, PrivacyProfile.balanced);
  });
}
