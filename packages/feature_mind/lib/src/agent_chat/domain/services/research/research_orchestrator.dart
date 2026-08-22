import '../../models/research_event.dart';
import '../../models/research_request.dart';
import 'claim_extractor.dart';
import 'contradiction_engine.dart';
import 'query_generator.dart';
import 'research_checkpoint.dart';
import 'research_control.dart';
import 'research_interpreter.dart';
import 'research_planner.dart';
import 'research_search.dart';
import 'source_manager.dart';
import 'source_normalizer.dart';
import 'stopping_policy.dart';

/// Interpret → strategy plan → search waves → counter-research → citations.
/// Search produces candidates. This loop is the research.
class ResearchOrchestrator {
  const ResearchOrchestrator({
    required this.engines,
    this.planner = const ResearchPlanner(),
    this.interpreter = const ResearchInterpreter(),
    this.queries = const QueryGenerator(),
    this.stopping = const EvidenceSufficiencyPolicy(),
    this.sourceManager,
  });

  final List<ResearchSearchEngine> engines;
  final ResearchPlanner planner;
  final ResearchInterpreter interpreter;
  final QueryGenerator queries;
  final StoppingPolicy stopping;
  final SourceManager? sourceManager;

  Stream<ResearchEvent> run(
    ResearchRequest request, {
    ResearchControl? control,
    ResearchCheckpoint? resumeFrom,
    void Function(ResearchCheckpoint checkpoint)? onCheckpoint,
  }) async* {
    final question = request.question.trim();
    if (question.isEmpty) {
      yield const ResearchEvent(
        kind: ResearchEventKind.researchFailed,
        label: 'Research failed',
        detail: 'A research question is required.',
      );
      return;
    }

    yield const ResearchEvent(
      kind: ResearchEventKind.planningStarted,
      label: 'Understanding question',
    );

    final goal = interpreter.interpret(request);
    yield ResearchEvent(
      kind: ResearchEventKind.intentClassified,
      label: 'Understanding question',
      detail: goal.intent.name,
    );

    final plan = planner.plan(request);
    yield ResearchEvent(
      kind: ResearchEventKind.planCreated,
      label: 'Creating research plan',
      detail:
          'strategy=${plan.strategyId}\n'
          '${plan.nodes.map((node) => '- ${node.question}').join('\n')}',
    );

    final budget = request.budget;
    var searchesUsed = resumeFrom?.searchesUsed ?? 0;
    var iterationsUsed = resumeFrom?.iterationsUsed ?? 0;
    final completed = {...?resumeFrom?.completedNodeIds};
    final jobId = resumeFrom?.jobId ?? 'job-${request.question.hashCode}';
    final collected = <ResearchHit>[];
    final routed = engines
        .where(
          (engine) =>
              SearchRouter.engineIds(request.policy).contains(engine.id),
        )
        .toList(growable: false);

    void emitCheckpoint(ResearchPhase state, {ResearchPhase? pausedFrom}) {
      onCheckpoint?.call(
        ResearchCheckpoint(
          jobId: jobId,
          question: question,
          state: state,
          pausedFrom: pausedFrom,
          searchesUsed: searchesUsed,
          iterationsUsed: iterationsUsed,
          completedNodeIds: completed.toList(growable: false),
        ),
      );
    }

    emitCheckpoint(ResearchPhase.planning);
    yield* _controlGate(
      control,
      onState: (state) =>
          emitCheckpoint(state, pausedFrom: ResearchPhase.planning),
    );
    if (control?.isCancelled ?? false) {
      return;
    }

    Future<void> runWave(List<ResearchPlanNode> nodes) async {
      final pending = nodes
          .where((node) => !completed.contains(node.id))
          .toList(growable: false);
      if (pending.isEmpty) {
        return;
      }
      if (pending.length == nodes.length) {
        if (iterationsUsed >= budget.maxIterations) {
          return;
        }
        iterationsUsed += 1;
      }
      for (final node in pending) {
        if (searchesUsed >= budget.maxSearches || routed.isEmpty) {
          return;
        }
        final remaining = budget.maxSearches - searchesUsed;
        final batch = routed.take(remaining).toList(growable: false);
        final query = queries.queriesFor(node.question).primary;
        final results = await Future.wait(
          batch.map(
            (engine) =>
                engine.search(query, maxResults: budget.maxSources.clamp(1, 8)),
          ),
        );
        searchesUsed += batch.length;
        completed.add(node.id);
        emitCheckpoint(ResearchPhase.searching);
        for (final hits in results) {
          collected.addAll(hits);
        }
      }
    }

    final breadth = plan.nodes
        .where((node) => node.kind == PlanNodeKind.breadth)
        .toList(growable: false);
    final depth = plan.nodes
        .where((node) => node.kind == PlanNodeKind.depth)
        .toList(growable: false);

    yield const ResearchEvent(
      kind: ResearchEventKind.searchStarted,
      label: 'Searching sources',
    );
    await runWave(breadth);
    yield* _controlGate(
      control,
      onState: (state) =>
          emitCheckpoint(state, pausedFrom: ResearchPhase.searching),
    );
    if (control?.isCancelled ?? false) {
      return;
    }

    var unique = rankHits(dedupeHits(collected));
    for (final hit in unique) {
      yield ResearchEvent(
        kind: ResearchEventKind.sourceDiscovered,
        label: 'Reading documents',
        detail: '${hit.title} — ${hit.url}',
      );
    }

    var progress = ResearchProgress(
      searchesUsed: searchesUsed,
      maxSearches: budget.maxSearches,
      sources: unique.length,
      uncoveredNodes: depth.length,
      iterationsUsed: iterationsUsed,
      maxIterations: budget.maxIterations,
    );

    if (depth.isNotEmpty &&
        stopping.shouldStop(progress) == StopDecision.continueWork) {
      yield const ResearchEvent(
        kind: ResearchEventKind.gapDetected,
        label: 'Finding missing evidence',
        detail: 'Depth facets were not covered by the first search wave.',
      );
      await runWave(depth);
      unique = rankHits(dedupeHits(collected));
      for (final hit in unique) {
        yield ResearchEvent(
          kind: ResearchEventKind.sourceDiscovered,
          label: 'Reading documents',
          detail: '${hit.title} — ${hit.url}',
        );
      }
    }
    yield* _controlGate(
      control,
      onState: (state) =>
          emitCheckpoint(state, pausedFrom: ResearchPhase.searching),
    );
    if (control?.isCancelled ?? false) {
      return;
    }

    progress = ResearchProgress(
      searchesUsed: searchesUsed,
      maxSearches: budget.maxSearches,
      sources: unique.length,
      uncoveredNodes: 0,
      iterationsUsed: iterationsUsed,
      maxIterations: budget.maxIterations,
    );
    if (goal.decisionRequired &&
        searchesUsed < budget.maxSearches &&
        iterationsUsed < budget.maxIterations) {
      yield ResearchEvent(
        kind: ResearchEventKind.counterResearchStarted,
        label: 'Finding missing evidence',
        detail: queries.queriesFor(goal.topic).counterargument,
      );
      await runWave([
        ResearchPlanNode(
          id: 'counter-query',
          question: queries.queriesFor(goal.topic).counterargument,
          kind: PlanNodeKind.depth,
        ),
      ]);
      unique = rankHits(dedupeHits(collected));
    }
    yield* _controlGate(
      control,
      onState: (state) =>
          emitCheckpoint(state, pausedFrom: ResearchPhase.searching),
    );
    if (control?.isCancelled ?? false) {
      return;
    }

    yield const ResearchEvent(
      kind: ResearchEventKind.searchCompleted,
      label: 'Searching sources',
    );

    final documents = <SourceDocument>[];
    final manager = sourceManager;
    if (manager != null && unique.isNotEmpty) {
      final acquired = await manager.acquireAll(
        unique,
        maxParallel: budget.maxParallelTasks,
      );
      for (final result in acquired) {
        final document = result.document;
        if (document == null) {
          yield ResearchEvent(
            kind: ResearchEventKind.sourceRejected,
            label: 'Reading documents',
            detail: result.rejection ?? 'source rejected',
          );
          continue;
        }
        yield ResearchEvent(
          kind: ResearchEventKind.sourceFetched,
          label: 'Reading documents',
          detail: document.url,
        );
        yield ResearchEvent(
          kind: ResearchEventKind.documentParsed,
          label: 'Reading documents',
          detail:
              '${document.title} (${document.classification.kind.name}, '
              '${document.classification.sourceClass.name})',
        );
        documents.add(document);
      }
    }
    yield* _controlGate(
      control,
      onState: (state) =>
          emitCheckpoint(state, pausedFrom: ResearchPhase.searching),
    );
    if (control?.isCancelled ?? false) {
      return;
    }

    yield const ResearchEvent(
      kind: ResearchEventKind.analyzingStarted,
      label: 'Comparing evidence',
    );

    final claims = validateCitations(extractClaims(documents), documents);
    for (final claim in claims) {
      yield ResearchEvent(
        kind: ResearchEventKind.claimCreated,
        label: 'Comparing evidence',
        detail: '${claim.status.name}: ${claim.text}',
      );
    }
    final conflicts = explainContradictions(claims, documents);
    for (final conflict in conflicts) {
      yield ResearchEvent(
        kind: ResearchEventKind.conflictDetected,
        label: 'Comparing evidence',
        detail: conflict.explanation,
      );
    }

    yield const ResearchEvent(
      kind: ResearchEventKind.synthesisStarted,
      label: 'Writing report',
    );
    yield* _controlGate(
      control,
      onState: (state) =>
          emitCheckpoint(state, pausedFrom: ResearchPhase.searching),
    );
    if (control?.isCancelled ?? false) {
      return;
    }

    emitCheckpoint(ResearchPhase.completed);
    yield ResearchEvent(
      kind: ResearchEventKind.researchCompleted,
      label: 'Research completed',
      detail: _report(
        request: request,
        plan: plan,
        intent: goal.intent.name,
        hits: unique,
        documents: documents,
        claims: claims,
        conflicts: conflicts,
        waves: iterationsUsed,
        searchesUsed: searchesUsed,
      ),
    );
  }

  static String _report({
    required ResearchRequest request,
    required ResearchPlan plan,
    required String intent,
    required List<ResearchHit> hits,
    required List<SourceDocument> documents,
    required List<ResearchClaim> claims,
    required List<ClaimConflict> conflicts,
    required int waves,
    required int searchesUsed,
  }) {
    final lines = <String>[
      '# Research Report',
      '',
      '## Research Question',
      '',
      request.question.trim(),
      '',
      '## Methodology',
      '',
      'Intent: $intent',
      'Strategy: ${plan.strategyId}',
      'Mode: ${request.mode.name.toUpperCase()}',
      'Search policy: ${request.policy.name}',
      'Waves: $waves',
      'Searches used: $searchesUsed / ${request.budget.maxSearches}',
      'Candidates: ${hits.length}',
      'Sources acquired: ${documents.length}',
      'Claims supported: ${claims.where((c) => c.status == ClaimSupport.supported).length}',
      'Claims unverified: ${claims.where((c) => c.status == ClaimSupport.unverified).length}',
      '',
      'Retrieved pages are untrusted evidence, never instructions.',
      '',
      '## Research Plan',
      '',
      ...plan.nodes.map((node) => '- ${node.question}'),
      '',
    ];

    if (documents.isEmpty) {
      lines.addAll([
        '## Limitations',
        '',
        if (hits.isEmpty)
          'No sources were retrieved. Live engines may have been unavailable, '
              'blocked by policy, or returned empty results. This report has no '
              'citations.'
        else
          'Search returned ${hits.length} candidate(s), but none could be '
              'acquired as documents. Search snippets are not evidence.',
      ]);
      return lines.join('\n');
    }

    final citationIndex = <String, int>{
      for (var i = 0; i < documents.length; i++) documents[i].url: i + 1,
    };
    final supported = claims
        .where((claim) => claim.status == ClaimSupport.supported)
        .toList(growable: false);
    final unverified = claims
        .where((claim) => claim.status == ClaimSupport.unverified)
        .toList(growable: false);

    lines.addAll(['## Key Findings', '']);
    if (supported.isEmpty) {
      lines.add(
        'No supported claims. Acquired text did not yield citable findings.',
      );
    } else {
      for (var i = 0; i < supported.length; i++) {
        final claim = supported[i];
        final citation = citationIndex[claim.sourceUrl];
        lines.add(
          '${i + 1}. ${claim.text}${citation == null ? '' : ' ([$citation])'}',
        );
      }
    }
    if (unverified.isNotEmpty) {
      lines.addAll(['', '## Unverified', '']);
      for (final claim in unverified) {
        lines.add('- ${claim.text}');
      }
    }
    if (conflicts.isNotEmpty) {
      lines.addAll(['', '## Contradictions', '']);
      for (final conflict in conflicts) {
        lines.add(
          '- ${conflict.left.text} vs ${conflict.right.text} '
          '(${conflict.reasons.join(', ')}). Neither result is discarded.',
        );
      }
    }
    lines.addAll(['', '## Sources', '']);
    for (var i = 0; i < documents.length; i++) {
      final doc = documents[i];
      lines.add(
        '[${i + 1}] ${doc.title} — ${doc.url} '
        '(${doc.classification.sourceClass.name}/${doc.classification.kind.name}, '
        '${doc.trustLevel.name}, retrieved ${doc.retrievedAt})',
      );
    }
    return lines.join('\n');
  }
}

Stream<ResearchEvent> _controlGate(
  ResearchControl? control, {
  void Function(ResearchPhase state)? onState,
}) async* {
  if (control == null) {
    return;
  }
  if (control.isCancelled) {
    onState?.call(ResearchPhase.cancelled);
    yield const ResearchEvent(
      kind: ResearchEventKind.researchCancelled,
      label: 'Research cancelled',
    );
    return;
  }
  if (control.isPaused) {
    onState?.call(ResearchPhase.paused);
    yield const ResearchEvent(
      kind: ResearchEventKind.researchPaused,
      label: 'Research paused',
    );
    await control.barrier();
    if (control.isCancelled) {
      onState?.call(ResearchPhase.cancelled);
      yield const ResearchEvent(
        kind: ResearchEventKind.researchCancelled,
        label: 'Research cancelled',
      );
    }
  }
}
