import '../models/research_event.dart';
import '../models/research_request.dart';
import 'research/research_checkpoint.dart';
import 'research/research_control.dart';
import 'research/research_library.dart';
import 'research/research_orchestrator.dart';
import 'research/research_service.dart';

/// Runs a Deep Research job. Implementations own orchestration, not prompts.
///
/// The production engine lives in Rust (`airo_mind_core::research`).
/// This Dart type is a stream facade over [ResearchService].
abstract class DeepResearchEngine {
  Stream<ResearchEvent> run(
    ResearchRequest request, {
    ResearchControl? control,
    ResearchCheckpoint? resumeFrom,
    void Function(ResearchCheckpoint checkpoint)? onCheckpoint,
    List<String> knownSourceUrls = const [],
    void Function(ResearchLibraryEntry entry)? onLibrary,
  });
}

typedef DeepResearchEngineFactory = DeepResearchEngine Function();

DeepResearchEngine createLocalDeepResearchEngine({Uri? searxngBaseUri}) {
  return LocalDeepResearchEngine(searxngBaseUri: searxngBaseUri);
}

/// Shim: Chat talks to [ResearchService], never to a research prompt.
class LocalDeepResearchEngine implements DeepResearchEngine {
  factory LocalDeepResearchEngine({
    ResearchService? service,
    ResearchOrchestrator? orchestrator,
    Uri? searxngBaseUri,
  }) {
    if (service != null && (orchestrator != null || searxngBaseUri != null)) {
      throw ArgumentError(
        'Inject a service or engine configuration, not both.',
      );
    }
    return LocalDeepResearchEngine._(
      service ??
          LocalResearchService(
            orchestrator: orchestrator,
            searxngBaseUri: searxngBaseUri,
          ),
    );
  }

  const LocalDeepResearchEngine._(this._service);

  final ResearchService _service;

  @override
  Stream<ResearchEvent> run(
    ResearchRequest request, {
    ResearchControl? control,
    ResearchCheckpoint? resumeFrom,
    void Function(ResearchCheckpoint checkpoint)? onCheckpoint,
    List<String> knownSourceUrls = const [],
    void Function(ResearchLibraryEntry entry)? onLibrary,
  }) => _service.start(
    request,
    control: control,
    resumeFrom: resumeFrom,
    onCheckpoint: onCheckpoint,
    knownSourceUrls: knownSourceUrls,
    onLibrary: onLibrary,
  );
}
