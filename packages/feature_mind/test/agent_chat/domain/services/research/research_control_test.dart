import 'dart:async';

import 'package:feature_mind/src/agent_chat/domain/models/research_event.dart';
import 'package:feature_mind/src/agent_chat/domain/models/research_request.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/research_checkpoint.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/research_control.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/research_orchestrator.dart';
import 'package:feature_mind/src/agent_chat/domain/services/research/research_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cancel during search does not write a completed report', () async {
    final control = ResearchControl();
    final hanging = _HangingEngine();
    final eventsFuture = ResearchOrchestrator(engines: [hanging])
        .run(
          const ResearchRequest(
            question: 'What is Qwen?',
            mode: ResearchMode.quick,
          ),
          control: control,
        )
        .toList();

    await hanging.started.future;
    control.cancel();
    hanging.release.complete();

    final events = await eventsFuture;
    expect(
      events.map((event) => event.kind),
      contains(ResearchEventKind.researchCancelled),
    );
    expect(
      events.map((event) => event.kind),
      isNot(contains(ResearchEventKind.researchCompleted)),
    );
  });

  test('pause then resume continues to a completed report', () async {
    final control = ResearchControl();
    final hanging = _HangingEngine();
    final events = <ResearchEvent>[];
    final done = ResearchOrchestrator(engines: [hanging])
        .run(
          const ResearchRequest(
            question: 'What is Qwen?',
            mode: ResearchMode.quick,
          ),
          control: control,
        )
        .listen(events.add);

    await hanging.started.future;
    control.pause();
    hanging.release.complete();
    await _until(events, ResearchEventKind.researchPaused);
    control.resume();
    await done.asFuture();
    expect(events.last.kind, ResearchEventKind.researchCompleted);
  });

  test('resume from a checkpoint skips completed plan nodes', () async {
    final searched = <String>[];
    final events =
        await ResearchOrchestrator(
              engines: [_CountingQueryEngine(searched: searched)],
            )
            .run(
              const ResearchRequest(
                question: 'Compare Qwen and Llama',
                mode: ResearchMode.quick,
              ),
              resumeFrom: const ResearchCheckpoint(
                jobId: 'job-1',
                question: 'Compare Qwen and Llama',
                state: ResearchPhase.paused,
                pausedFrom: ResearchPhase.searching,
                searchesUsed: 1,
                iterationsUsed: 1,
                completedNodeIds: ['s0'],
              ),
            )
            .toList();

    expect(events.last.kind, ResearchEventKind.researchCompleted);
    expect(searched, hasLength(1));
    expect(searched.single.toLowerCase(), isNot(startsWith('qwen')));
  });
}

Future<void> _until(List<ResearchEvent> events, ResearchEventKind kind) async {
  for (var i = 0; i < 100; i++) {
    if (events.any((event) => event.kind == kind)) {
      return;
    }
    await Future<void>.delayed(Duration.zero);
  }
  fail('never saw $kind in ${events.map((event) => event.kind).toList()}');
}

class _CountingQueryEngine implements ResearchSearchEngine {
  _CountingQueryEngine({required this.searched});

  final List<String> searched;

  @override
  String get id => 'wikipedia';

  @override
  Future<List<ResearchHit>> search(String query, {int maxResults = 5}) async {
    searched.add(query);
    return const [];
  }
}

class _HangingEngine implements ResearchSearchEngine {
  final started = Completer<void>();
  final release = Completer<void>();

  @override
  String get id => 'wikipedia';

  @override
  Future<List<ResearchHit>> search(String query, {int maxResults = 5}) async {
    if (!started.isCompleted) {
      started.complete();
    }
    await release.future;
    return const [
      ResearchHit(
        engineId: 'wikipedia',
        url: 'https://en.wikipedia.org/wiki/Qwen',
        title: 'Qwen',
        snippet: 'candidate only',
      ),
    ];
  }
}
