import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import '../export/domain/meeting_markdown_renderer.dart' show formatTimestamp;
import '../mind_diarization.dart' show formatMindSpeakerLabel;
import '../whisper/api/meetings.dart' as rust;
import 'evidence_resolver.dart';
import 'meeting_ir_user_edits.dart';

/// MoM sections rendered from Meeting IR (#1657 UI / #1658), not free-form
/// minutes text.
///
/// Decisions, action items, and metrics each carry evidence segment ids.
/// Empty lists still render a section title + empty hint so the product
/// surface is discoverable. Tapping evidence notifies [onEvidence] so the
/// transcript can highlight / optionally seek; action rows also show a
/// copyable/tappable clock when a segment resolves.
class MeetingIrMomSections extends StatelessWidget {
  const MeetingIrMomSections({
    super.key,
    required this.decisions,
    required this.actionItems,
    required this.metrics,
    required this.edits,
    required this.segmentsById,
    required this.onEvidence,
    required this.onToggleAction,
    required this.onEditAction,
    this.busyActionId,
    this.formatClock = _defaultEvidenceClock,
  });

  final List<rust.MeetingDecisionRecord> decisions;
  final List<rust.MeetingActionItemRecord> actionItems;
  final List<rust.MeetingMetricRecord> metrics;
  final MeetingIrUserEdits edits;
  final Map<String, TranscriptSegmentView> segmentsById;
  final void Function(List<String> evidenceSegmentIds) onEvidence;
  final void Function(rust.MeetingActionItemRecord item) onToggleAction;
  final void Function(rust.MeetingActionItemRecord item) onEditAction;
  final String? busyActionId;
  final String Function(int startMs) formatClock;

  static String _defaultEvidenceClock(int ms) {
    final totalSeconds = (ms < 0 ? 0 : ms) ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  String? _clockFor(List<String> evidenceSegmentIds) {
    for (final id in evidenceSegmentIds) {
      final segment = segmentsById[id];
      if (segment != null) return formatClock(segment.startMs);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _IrSectionTitle('Decisions'),
        if (decisions.isEmpty)
          const _IrEmptyHint('No decisions recorded.')
        else
          for (final d in decisions)
            _DecisionTile(
              decision: d,
              onTap: () => onEvidence(d.evidenceSegmentIds),
            ),
        const SizedBox(height: 16),
        const _IrSectionTitle('Action items'),
        if (actionItems.isEmpty)
          const _IrEmptyHint('No action items recorded.')
        else
          for (final item in actionItems)
            _ActionTile(
              item: item,
              task: edits.taskFor(item),
              owner: edits.ownerFor(item),
              evidenceClock: _clockFor(item.evidenceSegmentIds),
              busy: busyActionId == item.id,
              onToggle: () => onToggleAction(item),
              onEvidence: () => onEvidence(item.evidenceSegmentIds),
              onEdit: () => onEditAction(item),
            ),
        const SizedBox(height: 16),
        const _IrSectionTitle('Metrics'),
        if (metrics.isEmpty)
          const _IrEmptyHint('No metrics recorded.')
        else
          for (final m in metrics)
            _MetricTile(
              metric: m,
              onTap: () => onEvidence(m.evidenceSegmentIds),
            ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _IrEmptyHint extends StatelessWidget {
  const _IrEmptyHint(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

class _IrSectionTitle extends StatelessWidget {
  const _IrSectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}

class _DecisionTile extends StatelessWidget {
  const _DecisionTile({required this.decision, required this.onTap});

  final rust.MeetingDecisionRecord decision;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = switch (decision.status) {
      rust.MeetingDecisionStatus.proposed => 'Proposed',
      rust.MeetingDecisionStatus.agreed => 'Agreed',
      rust.MeetingDecisionStatus.rejected => 'Rejected',
      rust.MeetingDecisionStatus.deferred_ => 'Deferred',
    };
    return AiroSurface(
      level: AiroSurfaceLevel.raised,
      onTap: onTap,
      semanticLabel: 'Decision: ${decision.statement}. $status. Show evidence.',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.gavel_outlined,
              size: 20,
              color: AiroDomainTokens.of(context).accent,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(decision.statement),
                  const SizedBox(height: 4),
                  Text(status, style: Theme.of(context).textTheme.labelMedium),
                ],
              ),
            ),
            const Icon(Icons.link, size: 18),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.item,
    required this.task,
    required this.owner,
    required this.evidenceClock,
    required this.busy,
    required this.onToggle,
    required this.onEvidence,
    required this.onEdit,
  });

  final rust.MeetingActionItemRecord item;
  final String task;
  final String? owner;
  final String? evidenceClock;
  final bool busy;
  final VoidCallback onToggle;
  final VoidCallback onEvidence;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final done = item.status == rust.MeetingActionStatus.done;
    return AiroSurface(
      level: AiroSurfaceLevel.raised,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (busy)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              Checkbox(
                key: Key('meeting_ir_action_check_${item.id}'),
                value: done,
                onChanged: (_) => onToggle(),
              ),
            Expanded(
              child: InkWell(
                onTap: onEvidence,
                onLongPress: onEdit,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task,
                        style: done
                            ? Theme.of(context).textTheme.bodyLarge?.copyWith(
                                decoration: TextDecoration.lineThrough,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              )
                            : Theme.of(context).textTheme.bodyLarge,
                      ),
                      if (owner != null && owner!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          owner!,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ],
                      if (item.due != null && item.due!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Due ${item.due}',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (evidenceClock != null)
              TextButton(
                key: Key('meeting_ir_action_clock_${item.id}'),
                onPressed: onEvidence,
                child: Text(evidenceClock!),
              ),
            IconButton(
              key: Key('meeting_ir_action_edit_${item.id}'),
              tooltip: 'Edit action',
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.metric, required this.onTap});

  final rust.MeetingMetricRecord metric;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AiroSurface(
      level: AiroSurfaceLevel.raised,
      onTap: onTap,
      semanticLabel: 'Number: ${metric.name} ${metric.value}. Show evidence.',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(
              Icons.numbers,
              size: 20,
              color: AiroDomainTokens.of(context).accent,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text('${metric.name}: ${metric.value}')),
            const Icon(Icons.link, size: 18),
          ],
        ),
      ),
    );
  }
}

/// Timestamped transcript lines with optional evidence highlighting.
class MeetingIrTranscriptList extends StatelessWidget {
  const MeetingIrTranscriptList({
    super.key,
    required this.segments,
    required this.highlightedIds,
    required this.segmentKeys,
    this.fallbackTranscript = '',
  });

  final List<TranscriptSegmentView> segments;
  final Set<String> highlightedIds;
  final Map<String, GlobalKey> segmentKeys;
  final String fallbackTranscript;

  @override
  Widget build(BuildContext context) {
    if (segments.isEmpty) {
      if (fallbackTranscript.trim().isEmpty) {
        return const SizedBox.shrink();
      }
      return SelectableText(fallbackTranscript.trim());
    }

    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final segment in segments)
          Container(
            key: segmentKeys[segment.id],
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: highlightedIds.contains(segment.id)
                  ? scheme.tertiaryContainer
                  : null,
              borderRadius: BorderRadius.circular(8),
              border: highlightedIds.contains(segment.id)
                  ? Border.all(color: scheme.tertiary)
                  : null,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatTimestamp(segment.startMs),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (segment.speakerLabel != null) ...[
                  const SizedBox(width: 8),
                  Chip(
                    key: Key('meeting_ir_speaker_${segment.id}'),
                    label: Text(
                      formatMindSpeakerLabel(segment.speakerLabel!),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                  ),
                ],
                const SizedBox(width: 8),
                Expanded(
                  child: SelectableText(
                    segment.text.trim(),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Lightweight view of a transcript segment for the MoM UI (no Rust import
/// required by callers that already mapped wire types).
@immutable
class TranscriptSegmentView {
  const TranscriptSegmentView({
    required this.id,
    required this.startMs,
    required this.endMs,
    required this.text,
    this.speakerLabel,
  });

  final String id;
  final int startMs;
  final int endMs;
  final String text;

  /// Diarization label (`sp0`, `sp1`, …). Null before Wave 3 wiring.
  final String? speakerLabel;

  factory TranscriptSegmentView.fromEvidence(EvidenceHit hit) =>
      TranscriptSegmentView(
        id: hit.segmentId,
        startMs: hit.startMs,
        endMs: hit.endMs,
        text: hit.text,
      );
}

/// Banner when the device cannot run a local LLM for extraction (#1658).
class MeetingIrLowTierBanner extends StatelessWidget {
  const MeetingIrLowTierBanner({
    super.key,
    required this.onUseCloud,
    required this.onStayLocal,
  });

  final VoidCallback onUseCloud;
  final VoidCallback onStayLocal;

  @override
  Widget build(BuildContext context) {
    return AiroSurface(
      level: AiroSurfaceLevel.raised,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'This device is below the on-device LLM tier',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Text(
            'Meeting extraction can run in the cloud with your consent, '
            'or you can keep everything local and review the transcript only.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              FilledButton(
                key: const Key('meeting_ir_cloud_fallback'),
                onPressed: onUseCloud,
                child: const Text('Use cloud'),
              ),
              OutlinedButton(
                key: const Key('meeting_ir_stay_local'),
                onPressed: onStayLocal,
                child: const Text('Stay local'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
