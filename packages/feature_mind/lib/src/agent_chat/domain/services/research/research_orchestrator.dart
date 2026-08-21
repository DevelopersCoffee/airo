import '../../models/research_event.dart';
import '../../models/research_request.dart';
import 'claim_extractor.dart';
import 'query_generator.dart';
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

  Stream<ResearchEvent> run(ResearchRequest request) async* {
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
    var searchesUsed = 0;
    var iterationsUsed = 0;
    final collected = <ResearchHit>[];
    final routed = engines
        .where(
          (engine) =>
              SearchRouter.engineIds(request.policy).contains(engine.id),
        )
        .toList(growable: false);

    Future<void> runWave(List<ResearchPlanNode> nodes) async {
      for (final node in nodes) {
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
    if (breadth.isNotEmpty && iterationsUsed < budget.maxIterations) {
      iterationsUsed += 1;
      await runWave(breadth);
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
      iterationsUsed += 1;
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

    progress = ResearchProgress(
      searchesUsed: searchesUsed,
      maxSearches: budget.maxSearches,
      sources: unique.length,
      uncoveredNodes: 0,
      iterationsUsed: iterationsUsed,
      maxIterations: budget.maxIterations,
    );
    if (goal.decisionRequired &&
        stopping.shouldStop(progress) == StopDecision.continueWork) {
      yield ResearchEvent(
        kind: ResearchEventKind.counterResearchStarted,
        label: 'Finding missing evidence',
        detail: queries.queriesFor(goal.topic).counterargument,
      );
      iterationsUsed += 1;
      await runWave([
        ResearchPlanNode(
          id: 'counter-query',
          question: queries.queriesFor(goal.topic).counterargument,
          kind: PlanNodeKind.depth,
        ),
      ]);
      unique = rankHits(dedupeHits(collected));
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

    yield const ResearchEvent(
      kind: ResearchEventKind.synthesisStarted,
      label: 'Writing report',
    );

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
