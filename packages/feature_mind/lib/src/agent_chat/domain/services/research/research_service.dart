import '../../models/research_event.dart';
import '../../models/research_request.dart';
import 'arxiv_search_engine.dart';
import 'research_checkpoint.dart';
import 'research_control.dart';
import 'research_http.dart';
import 'research_orchestrator.dart';
import 'semantic_scholar_search_engine.dart';
import 'source_manager.dart';
import 'wikipedia_search_engine.dart';

/// Flutter-facing Deep Research API. The model does not own this workflow.
///
/// Production execution lives in Rust (`airo_mind_core::research::ResearchEngine`).
/// HTTP search/fetch stays outside that std-only crate. This Dart type is the
/// stream shim Chat uses; it must not become a research prompt.
abstract class ResearchService {
  Stream<ResearchEvent> start(
    ResearchRequest request, {
    ResearchControl? control,
    ResearchCheckpoint? resumeFrom,
    void Function(ResearchCheckpoint checkpoint)? onCheckpoint,
  });
}

/// I/O adapter: allowlisted HTTPS search + fetch, then the in-process
/// orchestrator. Replaced by FFI once the llama `api` surface exposes
/// `ResearchEngine`.
class LocalResearchService implements ResearchService {
  LocalResearchService({ResearchOrchestrator? orchestrator})
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
  Stream<ResearchEvent> start(
    ResearchRequest request, {
    ResearchControl? control,
    ResearchCheckpoint? resumeFrom,
    void Function(ResearchCheckpoint checkpoint)? onCheckpoint,
  }) => _orchestrator.run(
    request,
    control: control,
    resumeFrom: resumeFrom,
    onCheckpoint: onCheckpoint,
  );
}
