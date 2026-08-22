import 'package:feature_mind/src/agent_chat/domain/models/research_event.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/research_checkpoint.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('checkpoint record matches the rust v1 operation-log payload', () {
    const checkpoint = ResearchCheckpoint(
      jobId: 'job-1',
      question: 'Pixel 9 offline LLM',
      state: ResearchPhase.paused,
      pausedFrom: ResearchPhase.analyzing,
      searchesUsed: 2,
      iterationsUsed: 1,
      completedNodeIds: ['n1', 'n2'],
    );

    final restored = ResearchCheckpoint.fromRecord(checkpoint.toRecord());
    expect(restored, checkpoint);
    expect(
      checkpoint.toRecord(),
      'v1\u{1f}job-1\u{1f}Pixel 9 offline LLM\u{1f}paused\u{1f}analyzing\u{1f}2\u{1f}1\u{1f}n1,n2',
    );
  });
}
