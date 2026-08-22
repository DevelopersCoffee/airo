import 'package:feature_mind/src/agent_chat/domain/models/research_event.dart';
import 'package:feature_mind/src/agent_chat/domain/models/research_request.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/research_checkpoint.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/rust_research_mapping.dart';
import 'package:feature_mind/src/llama/api/research.dart' as frb;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FRB completed maps to Dart researchCompleted', () {
    final mapped = mapFrbResearchEvent(
      const frb.FrbResearchEvent(
        kind: frb.FrbResearchEventKind.completed,
        jobId: 'job-1',
        label: 'Research completed',
        detail: '# Research Report',
      ),
    );
    expect(mapped.kind, ResearchEventKind.researchCompleted);
    expect(mapped.jobId, 'job-1');
  });

  test('research request maps mode and policy', () {
    final frbRequest = mapResearchRequest(
      const ResearchRequest(
        question: 'What is Qwen?',
        mode: ResearchMode.quick,
        policy: SearchPolicy.privacyFirst,
      ),
    );
    expect(frbRequest.mode, frb.FrbResearchMode.quick);
    expect(frbRequest.policy, frb.FrbSearchPolicy.privacyFirst);
  });

  test('research checkpoint maps to FRB record wire', () {
    const checkpoint = ResearchCheckpoint(
      jobId: 'job-42',
      question: 'What is Qwen?',
      state: ResearchPhase.searching,
      searchesUsed: 2,
      iterationsUsed: 1,
      mode: ResearchMode.deep,
      policy: SearchPolicy.balanced,
    );
    final mapped = mapResearchCheckpoint(checkpoint);
    expect(
      ResearchCheckpoint.fromRecord(mapped.record),
      checkpoint,
    );
  });
}
