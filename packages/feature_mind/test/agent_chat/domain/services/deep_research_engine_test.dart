import 'package:feature_mind/src/agent_chat/domain/models/research_event.dart';
import 'package:feature_mind/src/agent_chat/domain/models/research_request.dart';
import 'package:feature_mind/src/agent_chat/domain/services/deep_research_engine.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/research_checkpoint.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/research_control.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/research_library.dart';
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

  test('the engine forwards known library urls and onLibrary', () async {
    final service = _RecordingService();
    void onLibrary(ResearchLibraryEntry entry) {}
    final DeepResearchEngine engine = LocalDeepResearchEngine(service: service);
    await engine
        .run(
          const ResearchRequest(question: 'What is Qwen?'),
          knownSourceUrls: const ['https://en.wikipedia.org/wiki/Qwen'],
          onLibrary: onLibrary,
        )
        .toList();

    expect(service.knownSourceUrls, ['https://en.wikipedia.org/wiki/Qwen']);
    expect(service.onLibrary, same(onLibrary));
  });
}

class _RecordingService implements ResearchService {
  List<String> knownSourceUrls = const [];
  void Function(ResearchLibraryEntry entry)? onLibrary;

  @override
  Stream<ResearchEvent> start(
    ResearchRequest request, {
    ResearchControl? control,
    ResearchCheckpoint? resumeFrom,
    void Function(ResearchCheckpoint checkpoint)? onCheckpoint,
    List<String> knownSourceUrls = const [],
    void Function(ResearchLibraryEntry entry)? onLibrary,
  }) async* {
    this.knownSourceUrls = knownSourceUrls;
    this.onLibrary = onLibrary;
    yield ResearchEvent(
      kind: ResearchEventKind.jobAdmitted,
      jobId: 'job-test',
      label: 'Research admitted',
      detail: request.question,
    );
  }
}
