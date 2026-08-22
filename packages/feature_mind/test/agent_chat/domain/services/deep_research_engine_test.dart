import 'package:feature_mind/src/agent_chat/domain/models/research_event.dart';
import 'package:feature_mind/src/agent_chat/domain/models/research_request.dart';
import 'package:feature_mind/src/agent_chat/domain/services/deep_research_engine.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/research_checkpoint.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/research_control.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/research_orchestrator.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/research_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('deep mode is a budget, not a hardcoded search count', () {
    const request = ResearchRequest(question: 'Compare Qwen, Llama and Gemma');
    expect(request.mode, ResearchMode.deep);
    expect(request.budget.maxSearches, 40);
    expect(request.budget.maxIterations, 8);
    expect(
      ResearchBudget.forMode(ResearchMode.quick).maxSearches,
      lessThan(request.budget.maxSearches),
    );
  });

  test('empty questions fail instead of inventing a report', () async {
    final events = await LocalDeepResearchEngine(
      orchestrator: const ResearchOrchestrator(engines: []),
    ).run(const ResearchRequest(question: '   ')).toList();
    expect(events.single.kind, ResearchEventKind.researchFailed);
  });

  test('the engine is a shim over ResearchService', () async {
    final events = await LocalDeepResearchEngine(
      service: _RecordingService(),
    ).run(const ResearchRequest(question: 'What is Qwen?')).toList();

    expect(events, hasLength(1));
    expect(events.single.kind, ResearchEventKind.jobAdmitted);
    expect(events.single.jobId, 'job-test');
  });
}

class _RecordingService implements ResearchService {
  @override
  Stream<ResearchEvent> start(
    ResearchRequest request, {
    ResearchControl? control,
    ResearchCheckpoint? resumeFrom,
    void Function(ResearchCheckpoint checkpoint)? onCheckpoint,
  }) async* {
    yield ResearchEvent(
      kind: ResearchEventKind.jobAdmitted,
      jobId: 'job-test',
      label: 'Research admitted',
      detail: request.question,
    );
  }
}
