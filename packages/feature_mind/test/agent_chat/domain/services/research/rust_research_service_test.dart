import 'package:feature_mind/src/agent_chat/domain/models/research_event.dart';
import 'package:feature_mind/src/agent_chat/domain/models/research_request.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/research_checkpoint.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/research_control.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/research_library.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/research_search.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/research_service.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/rust_research_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('RustResearchService delegates to fallback when injected', () async {
    final service = RustResearchService(
      engines: const [_FakeEngine()],
      fetch: (_) async => '<article><p>body</p></article>',
      fallback: _RecordingService(),
    );

    final events = await service
        .start(const ResearchRequest(question: 'What is Qwen?'))
        .toList();

    expect(events.single.kind, ResearchEventKind.researchCompleted);
  });
}

class _RecordingService implements ResearchService {
  @override
  Stream<ResearchEvent> start(
    ResearchRequest request, {
    ResearchControl? control,
    ResearchCheckpoint? resumeFrom,
    void Function(ResearchCheckpoint checkpoint)? onCheckpoint,
    List<String> knownSourceUrls = const [],
    void Function(ResearchLibraryEntry entry)? onLibrary,
  }) async* {
    yield const ResearchEvent(
      kind: ResearchEventKind.researchCompleted,
      detail: 'fallback',
    );
  }
}

class _FakeEngine implements ResearchSearchEngine {
  const _FakeEngine();

  @override
  String get id => 'wikipedia';

  @override
  Future<List<ResearchHit>> search(String query, {int maxResults = 5}) async {
    return const [];
  }
}
