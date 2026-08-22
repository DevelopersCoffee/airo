import 'dart:async';

import '../../models/research_event.dart';
import '../../models/research_request.dart';
import '../../../../llama/api/research.dart' as frb;
import 'research_checkpoint.dart';
import 'research_control.dart';
import 'research_library.dart';
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
    List<String> knownSourceUrls = const [],
    void Function(ResearchLibraryEntry entry)? onLibrary,
  }) async* {
    final fallback = _fallback;
    if (fallback != null) {
      yield* fallback.start(
        request,
        control: control,
        resumeFrom: resumeFrom,
        onCheckpoint: onCheckpoint,
        knownSourceUrls: knownSourceUrls,
        onLibrary: onLibrary,
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

    final jobId = resumeFrom?.jobId ??
        frb.researchStart(
          handle: handle,
          request: mapResearchRequest(request),
        );
    if (resumeFrom != null) {
      frb.researchRestore(
        handle: handle,
        checkpoint: mapResearchCheckpoint(resumeFrom),
      );
    }

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

    final fetchedUrls = <String>[];
    final findings = <String>[];

    try {
      await for (final event in frb.researchRun(
        handle: handle,
        jobId: jobId,
        knownSourceUrls: knownSourceUrls,
      )) {
        final mapped = mapFrbResearchEvent(event);
        _maybeEmitCheckpoint(handle, jobId, mapped.kind, onCheckpoint);
        if (mapped.kind == ResearchEventKind.sourceFetched) {
          fetchedUrls.add(mapped.detail);
        } else if (mapped.kind == ResearchEventKind.claimCreated &&
            mapped.detail.startsWith('supported: ')) {
          findings.add(mapped.detail.substring('supported: '.length));
        } else if (mapped.kind == ResearchEventKind.researchCompleted) {
          onLibrary?.call(
            ResearchLibraryEntry.fromQuestion(
              question: request.question,
              retrievedAt: DateTime.now().toUtc().toIso8601String(),
              sourceUrls: fetchedUrls,
              findings: findings,
            ),
          );
        }
        yield mapped;
      }
    } finally {
      controlTimer?.cancel();
    }
  }

  void _maybeEmitCheckpoint(
    frb.ResearchServiceHandle handle,
    String jobId,
    ResearchEventKind kind,
    void Function(ResearchCheckpoint checkpoint)? onCheckpoint,
  ) {
    if (onCheckpoint == null) {
      return;
    }
    const checkpointKinds = {
      ResearchEventKind.searchCompleted,
      ResearchEventKind.gapDetected,
      ResearchEventKind.researchPaused,
      ResearchEventKind.researchCompleted,
      ResearchEventKind.researchFailed,
      ResearchEventKind.researchCancelled,
    };
    if (!checkpointKinds.contains(kind)) {
      return;
    }
    final checkpoint = frb.researchCheckpoint(handle: handle, jobId: jobId);
    if (checkpoint != null) {
      onCheckpoint(ResearchCheckpoint.fromRecord(checkpoint.record));
    }
  }
}
