import '../models/research_event.dart';
import '../models/research_request.dart';
import 'research/arxiv_search_engine.dart';
import 'research/research_http.dart';
import 'research/research_orchestrator.dart';
import 'research/semantic_scholar_search_engine.dart';
import 'research/source_manager.dart';
import 'research/wikipedia_search_engine.dart';

/// Runs a Deep Research job. Implementations own orchestration, not prompts.
///
/// The production engine will live in Rust (`airo_mind_core::research`).
/// This Dart surface is the Flutter contract: typed request in, structured
/// events out. A huge "do research" prompt is not a valid implementation.
abstract class DeepResearchEngine {
  Stream<ResearchEvent> run(ResearchRequest request);
}

/// In-process research engine: planner + policy router + Wikipedia/arXiv.
class LocalDeepResearchEngine implements DeepResearchEngine {
  LocalDeepResearchEngine({ResearchOrchestrator? orchestrator})
    : _orchestrator =
          orchestrator ??
          ResearchOrchestrator(
            engines: [
              WikipediaSearchEngine(),
              ArxivSearchEngine(),
              SemanticScholarSearchEngine(),
            ],
            sourceManager: SourceManager(
              fetcher: const ResearchHttpClient().get,
            ),
          );

  final ResearchOrchestrator _orchestrator;

  @override
  Stream<ResearchEvent> run(ResearchRequest request) =>
      _orchestrator.run(request);
}
