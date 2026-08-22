import '../../models/research_event.dart';
import '../../models/research_request.dart';
import 'arxiv_search_engine.dart';
import 'local_memory_search_engine.dart';
import 'research_checkpoint.dart';
import 'research_control.dart';
import 'research_http.dart';
import 'research_library.dart';
import 'research_orchestrator.dart';
import 'searxng_search_engine.dart';
import 'semantic_scholar_search_engine.dart';
import 'source_manager.dart';
import 'wikipedia_search_engine.dart';
import '../../../runtime/ports/operation_log_port.dart';

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
    List<String> knownSourceUrls = const [],
    void Function(ResearchLibraryEntry entry)? onLibrary,
  });
}

/// I/O adapter: allowlisted HTTPS search + fetch, then the in-process
/// orchestrator. Replaced by FFI once the llama `api` surface exposes
/// `ResearchEngine`.
class LocalResearchService implements ResearchService {
  factory LocalResearchService({
    ResearchOrchestrator? orchestrator,
    Uri? searxngBaseUri,
    OperationLogPort? operationLogPort,
  }) {
    if (orchestrator != null &&
        (searxngBaseUri != null || operationLogPort != null)) {
      throw ArgumentError(
        'Inject either an orchestrator or engine configuration, not both.',
      );
    }
    return LocalResearchService._(
      orchestrator ??
          _defaultOrchestrator(
            searxngBaseUri: searxngBaseUri,
            operationLogPort: operationLogPort,
          ),
      hasConfiguredSearxng: searxngBaseUri != null,
    );
  }

  const LocalResearchService._(
    this._orchestrator, {
    required this.hasConfiguredSearxng,
  });

  final ResearchOrchestrator _orchestrator;
  final bool hasConfiguredSearxng;

  static ResearchOrchestrator _defaultOrchestrator({
    Uri? searxngBaseUri,
    OperationLogPort? operationLogPort,
  }) {
    return ResearchOrchestrator(
      engines: [
        WikipediaSearchEngine(),
        ArxivSearchEngine(),
        SemanticScholarSearchEngine(),
        if (operationLogPort != null)
          LocalMemorySearchEngine(operationLog: operationLogPort),
        if (searxngBaseUri != null)
          SearxngSearchEngine(baseUri: searxngBaseUri),
      ],
      sourceManager: SourceManager(fetcher: const ResearchHttpClient().get),
    );
  }

  @override
  Stream<ResearchEvent> start(
    ResearchRequest request, {
    ResearchControl? control,
    ResearchCheckpoint? resumeFrom,
    void Function(ResearchCheckpoint checkpoint)? onCheckpoint,
    List<String> knownSourceUrls = const [],
    void Function(ResearchLibraryEntry entry)? onLibrary,
  }) => _orchestrator.run(
    request,
    control: control,
    resumeFrom: resumeFrom,
    onCheckpoint: onCheckpoint,
    knownSourceUrls: knownSourceUrls,
    onLibrary: onLibrary,
  );
}
