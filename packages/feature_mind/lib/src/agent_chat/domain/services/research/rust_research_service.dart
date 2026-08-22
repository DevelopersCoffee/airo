import 'dart:async';

import '../../models/research_event.dart';
import '../../models/research_request.dart';
import '../../../../llama/api/research.dart' as frb;
import 'research_checkpoint.dart';
import 'research_control.dart';
import 'research_search.dart';
import 'research_service.dart';
import 'rust_research_mapping.dart';

/// Production [ResearchService]: Rust owns orchestration; Dart injects I/O.
///
/// When [fallback] is set (web/tests/pre-init), delegates to the Dart
/// orchestrator instead of calling the llama bridge.
class RustResearchService implements ResearchService {
  RustResearchService({
    required List<ResearchSearchEngine> engines,
    required Future<String> Function(Uri url) fetch,
    ResearchService? fallback,
  }) : _engines = engines,
       _fetch = fetch,
       _fallback = fallback;

  final List<ResearchSearchEngine> _engines;
  final Future<String> Function(Uri url) _fetch;
  final ResearchService? _fallback;
  frb.ResearchServiceHandle? _handle;

  @override
  Stream<ResearchEvent> start(
    ResearchRequest request, {
    ResearchControl? control,
    ResearchCheckpoint? resumeFrom,
    void Function(ResearchCheckpoint checkpoint)? onCheckpoint,
  }) async* {
    final fallback = _fallback;
    if (fallback != null) {
      yield* fallback.start(
        request,
        control: control,
        resumeFrom: resumeFrom,
        onCheckpoint: onCheckpoint,
      );
      return;
    }

    final handle = _handle ??= await frb.createResearchService(
      engineIds: _engines.map((engine) => engine.id).toList(growable: false),
      search: (engineId, searchRequest) async {
        final engine = _engines.firstWhere(
          (candidate) => candidate.id == engineId,
          orElse: () => throw StateError('unknown search engine: $engineId'),
        );
        final hits = await engine.search(
          searchRequest.query,
          maxResults: searchRequest.maxResults,
        );
        return frb.FrbSearchResponse(
          engineId: engineId,
          hits: hits
              .map(
                (hit) => frb.FrbSearchHit(
                  url: hit.url,
                  title: hit.title,
                  snippet: hit.snippet,
                ),
              )
              .toList(growable: false),
        );
      },
      fetch: (url) => _fetch(Uri.parse(url)),
    );

    final jobId = frb.researchStart(
      handle: handle,
      request: mapResearchRequest(request),
    );

    Timer? controlTimer;
    if (control != null) {
      var paused = control.isPaused;
      var cancelled = control.isCancelled;
      controlTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (control.isCancelled && !cancelled) {
          cancelled = true;
          frb.researchCancel(handle: handle, jobId: jobId);
        } else if (control.isPaused && !paused) {
          paused = true;
          frb.researchPause(handle: handle, jobId: jobId);
        } else if (!control.isPaused && paused) {
          paused = false;
          frb.researchResume(handle: handle, jobId: jobId);
        }
      });
    }

    try {
      await for (final event in frb.researchRun(handle: handle, jobId: jobId)) {
        yield mapFrbResearchEvent(event);
      }
    } finally {
      controlTimer?.cancel();
    }
  }
}
