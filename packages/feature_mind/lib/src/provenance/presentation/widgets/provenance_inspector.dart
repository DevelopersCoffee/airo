import 'dart:async';

import 'package:flutter/material.dart';

import '../../../runtime/models/context_models.dart';
import '../../../runtime/models/log_models.dart';
import '../../../runtime/models/projection_models.dart';
import '../../../runtime/ports/context_port.dart';
import '../../../runtime/ports/operation_log_port.dart';
import '../../../runtime/ports/projection_port.dart';
import '../../../widgets/mind_context_chip.dart';
import '../../../widgets/mind_palette.dart';
import '../../domain/models/entity_relation.dart';
import '../../domain/models/extracted_entity.dart';
import '../../domain/services/entity_extractor.dart';
import '../../domain/services/entity_relation_extractor.dart';
import '../../domain/services/model_entity_extractor.dart';
import 'entity_chip.dart';

/// Surfaces 09 (Context Workspace) and 11 (Everything Browser)'s provenance
/// Inspector.
///
/// Opened against one op. Per issue #1463, per selected op it shows: the
/// artefact title and a freshly re-verified signature state (never the
/// stored value, taken on trust — see [OperationLogPort.verify]); entities
/// extracted on-device; linked contexts from the hypergraph (rule R02); each
/// projection's own state, independently, because three projections can be
/// in three different states for the same op; and a replay-from-log action
/// that reports the duration it actually measured.
class ProvenanceInspector extends StatefulWidget {
  const ProvenanceInspector({
    super.key,
    required this.opSequence,
    required this.log,
    required this.contexts,
    required this.projections,
    this.extractor = const RuleBasedEntityExtractor(),
    this.model,
    this.relations = const EntityRelationExtractor(),
    this.onContextTap,
    this.onCitationTap,
  });

  /// The op under inspection.
  final int opSequence;

  final OperationLogPort log;
  final ContextPort contexts;
  final ProjectionPort projections;
  final EntityExtractor extractor;

  /// Optional loaded-GGUF pass. Null keeps the inspector on [extractor]
  /// (rules) only. When set, rule chips paint first;
  /// [EntityExtractionPipeline.runEnriched] then merges model mentions
  /// without blocking first paint. A missing model is not
  /// [EntityExtractionUnavailable] in this panel — rule chips stay. A
  /// throwing [extractor] still shows the unavailable banner.
  final ModelBackedEntityExtractor? model;
  final EntityRelationExtractor relations;

  /// Tapping a linked context chip (rule R02).
  final void Function(String contextId)? onContextTap;

  /// Tapping an entity's citation to jump back to the op that produced it.
  final void Function(int opSequence)? onCitationTap;

  @override
  State<ProvenanceInspector> createState() => _ProvenanceInspectorState();
}

class _ProvenanceInspectorState extends State<ProvenanceInspector> {
  late Future<MindOp?> _opFuture;

  @override
  void initState() {
    super.initState();
    _opFuture = widget.log.bySequence(widget.opSequence);
  }

  @override
  void didUpdateWidget(covariant ProvenanceInspector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.opSequence != widget.opSequence ||
        oldWidget.log != widget.log) {
      _opFuture = widget.log.bySequence(widget.opSequence);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<MindOp?>(
      future: _opFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final op = snapshot.data;
        if (op == null) {
          return _ProvenanceBroken(sequence: widget.opSequence);
        }
        return _InspectorBody(
          key: ValueKey(op.sequence),
          op: op,
          log: widget.log,
          contexts: widget.contexts,
          projections: widget.projections,
          extractor: widget.extractor,
          model: widget.model,
          relations: widget.relations,
          onContextTap: widget.onContextTap,
          onCitationTap: widget.onCitationTap,
        );
      },
    );
  }
}

/// State reached when the log has no op at the requested sequence — the
/// chain a citation or a deep link promised is not there to walk.
///
/// Named, not blank: the copy states why the chain might be broken rather
/// than leaving a person looking at an empty panel.
class _ProvenanceBroken extends StatelessWidget {
  const _ProvenanceBroken({required this.sequence});

  final int sequence;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(
        'Provenance chain broken — op $sequence is not in the log. It may '
        'have been shredded with its context, or this device has not '
        'replayed far enough to have it yet.',
        key: const Key('provenance.broken'),
        style: TextStyle(color: MindPalette.alarm),
      ),
    );
  }
}

class _InspectorBody extends StatefulWidget {
  const _InspectorBody({
    super.key,
    required this.op,
    required this.log,
    required this.contexts,
    required this.projections,
    required this.extractor,
    this.model,
    required this.relations,
    required this.onContextTap,
    required this.onCitationTap,
  });

  final MindOp op;
  final OperationLogPort log;
  final ContextPort contexts;
  final ProjectionPort projections;
  final EntityExtractor extractor;
  final ModelBackedEntityExtractor? model;
  final EntityRelationExtractor relations;
  final void Function(String contextId)? onContextTap;
  final void Function(int opSequence)? onCitationTap;

  @override
  State<_InspectorBody> createState() => _InspectorBodyState();
}

class _InspectorBodyState extends State<_InspectorBody> {
  late final Future<SignatureState> _signatureFuture;
  late final Future<List<MindContext>> _linkedContextsFuture;
  late final Future<List<ProjectionState>> _projectionsFuture;

  List<ExtractedEntity>? _entities;
  List<EntityRelation> _relations = const [];
  Object? _extractionError;
  int _enrichGeneration = 0;

  double? _replayProgress;
  Duration? _replayDuration;
  StreamSubscription<double>? _replaySub;

  static final TextStyle _sectionStyle = TextStyle(
    fontSize: 11,
    letterSpacing: 1,
    color: MindPalette.ink.withValues(alpha: 0.55),
  );

  @override
  void initState() {
    super.initState();
    // Re-verified fresh rather than read off `op.signature`: the console
    // shows the stored state elsewhere, but the inspector's job is to prove
    // it, not repeat it.
    _signatureFuture = widget.log.verify(widget.op.sequence);
    _linkedContextsFuture = _loadLinkedContexts();
    _projectionsFuture = widget.projections.states();
    _runExtraction();
  }

  void _runExtraction() {
    final text = widget.op.detail.isEmpty
        ? widget.op.title
        : '${widget.op.title}. ${widget.op.detail}';
    try {
      _entities = widget.extractor.extract(text);
      _relations = widget.relations.extractFrom(text, _entities!).relations;
    } on Object catch (error) {
      _extractionError = error;
      _relations = const [];
      return;
    }
    unawaited(_enrichIfModelLoaded(text));
  }

  Future<void> _enrichIfModelLoaded(String text) async {
    final model = widget.model;
    if (model == null) return;
    final generation = ++_enrichGeneration;
    try {
      final graph = await EntityExtractionPipeline(
        extractor: widget.extractor,
        model: model,
      ).runEnriched(text);
      if (!mounted || generation != _enrichGeneration) return;
      setState(() {
        _entities = graph.entities;
        _relations = graph.relations;
      });
    } on Object {
      // Keep rule chips. A loaded-GGUF miss is not the unavailable banner.
    }
  }

  Future<List<MindContext>> _loadLinkedContexts() async {
    if (widget.op.contextId.isEmpty) return const [];
    final links = await widget.contexts.linksFor(widget.op.contextId);
    final ids = links
        .map(
          (link) =>
              link.fromId == widget.op.contextId ? link.toId : link.fromId,
        )
        .toSet();
    final all = await widget.contexts.all();
    return all.where((c) => ids.contains(c.id)).toList(growable: false);
  }

  Future<void> _showProvenanceFor(ExtractedEntity entity) async {
    final hits = await widget.projections.search(
      entity.text,
      contextId: widget.op.contextId.isEmpty ? null : widget.op.contextId,
    );
    if (!mounted) return;
    if (hits.isEmpty) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          key: const Key('provenance.chain.broken'),
          content: Text(
            'Provenance chain broken — "${entity.text}" is not confirmed '
            'by the search index. The projection may be stale; try replay.',
          ),
        ),
      );
      return;
    }
    widget.onCitationTap?.call(hits.first.opSequence);
  }

  Future<void> _startReplay() async {
    setState(() {
      _replayProgress = 0;
      _replayDuration = null;
    });
    final stopwatch = Stopwatch()..start();
    await _replaySub?.cancel();
    _replaySub = widget.log
        .replayFrom(widget.op.sequence)
        .listen(
          (fraction) {
            if (!mounted) return;
            setState(() => _replayProgress = fraction);
          },
          onDone: () {
            stopwatch.stop();
            if (!mounted) return;
            setState(() {
              _replayProgress = null;
              // Measured, not configured — the panel prints what actually
              // happened, per the port's own contract.
              _replayDuration = stopwatch.elapsed;
            });
          },
        );
  }

  @override
  void dispose() {
    _replaySub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final op = widget.op;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            op.title,
            key: const Key('provenance.title'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            'op ${op.sequence} · ${op.deviceName}',
            style: TextStyle(
              fontSize: 11,
              color: MindPalette.ink.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          _buildSignature(),
          const SizedBox(height: 16),
          Text('EXTRACTED ENTITIES', style: _sectionStyle),
          const SizedBox(height: 8),
          _buildEntities(),
          const SizedBox(height: 16),
          Text('RELATIONS', style: _sectionStyle),
          const SizedBox(height: 8),
          _buildRelations(),
          const SizedBox(height: 16),
          Text('LINKED CONTEXTS', style: _sectionStyle),
          const SizedBox(height: 8),
          _buildLinkedContexts(),
          const SizedBox(height: 16),
          Text('PROJECTIONS TOUCHED', style: _sectionStyle),
          const SizedBox(height: 8),
          _buildProjections(),
          const SizedBox(height: 16),
          _buildReplay(),
        ],
      ),
    );
  }

  Widget _buildSignature() {
    return FutureBuilder<SignatureState>(
      future: _signatureFuture,
      builder: (context, snapshot) {
        final state = snapshot.data;
        if (state == null) {
          return const Text(
            'Verifying signature…',
            key: Key('provenance.signature.checking'),
          );
        }
        final label = switch (state) {
          SignatureState.verified => 'Signature verified',
          SignatureState.unverified => 'Signature UNVERIFIED',
          SignatureState.unsigned => 'UNSIGNED',
        };
        return Text(
          label,
          key: const Key('provenance.signature'),
          style: TextStyle(
            color: state == SignatureState.verified
                ? MindPalette.local
                : MindPalette.alarm,
          ),
        );
      },
    );
  }

  Widget _buildEntities() {
    if (_extractionError != null) {
      return Text(
        'Entity extraction is unavailable on this device.',
        key: const Key('provenance.entities.unavailable'),
        style: TextStyle(color: MindPalette.alarm),
      );
    }
    final entities = _entities ?? const [];
    if (entities.isEmpty) {
      return const Text(
        'No entities found in this op.',
        key: Key('provenance.entities.empty'),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: entities
          .map(
            (entity) => EntityChip(
              entity: entity,
              onTap: () => _showProvenanceFor(entity),
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _buildRelations() {
    if (_extractionError != null || _relations.isEmpty) {
      return const Text(
        'No relations found in this op.',
        key: Key('provenance.relations.empty'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _relations.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(
              _relations[i].toString(),
              key: Key('provenance.relation.$i'),
              style: const TextStyle(fontSize: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildLinkedContexts() {
    return FutureBuilder<List<MindContext>>(
      future: _linkedContextsFuture,
      builder: (context, snapshot) {
        final linked = snapshot.data;
        if (linked == null) {
          return const SizedBox(height: 24, child: LinearProgressIndicator());
        }
        if (linked.isEmpty) {
          return const Text(
            'No linked contexts.',
            key: Key('provenance.contexts.empty'),
          );
        }
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: linked
              .map(
                (c) => MindContextChip(
                  context: c,
                  onTap: () => widget.onContextTap?.call(c.id),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }

  Widget _buildProjections() {
    return FutureBuilder<List<ProjectionState>>(
      future: _projectionsFuture,
      builder: (context, snapshot) {
        final states = snapshot.data;
        if (states == null) {
          return const SizedBox(height: 24, child: LinearProgressIndicator());
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: states
              .map(
                (state) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    '${state.kind.name} · ${state.status.name}'
                    '${state.status == ProjectionStatus.rebuilding ? ' (${state.opsProcessed}/${state.opsTotal})' : ''}',
                    key: Key('provenance.projection.${state.kind.name}'),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }

  Widget _buildReplay() {
    if (_replayDuration != null) {
      final seconds = _replayDuration!.inMilliseconds / 1000;
      return Text(
        'Rebuilt in ${seconds.toStringAsFixed(1)}s. Projections are '
        'disposable — this always rebuilds in seconds.',
        key: const Key('provenance.replay.done'),
      );
    }
    if (_replayProgress != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Replaying from op ${widget.op.sequence}…'),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            key: const Key('provenance.replay.progress'),
            value: _replayProgress,
          ),
        ],
      );
    }
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        key: const Key('provenance.replay.button'),
        onPressed: _startReplay,
        child: const Text('Replay from log'),
      ),
    );
  }
}
