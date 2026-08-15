import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import 'bridges/mind_speech_bridge.dart' show TranscriptSegment;
import 'export/application/meeting_export_service.dart';
import 'export/data/meeting_export_gateway.dart';
import 'meeting_ir/evidence_resolver.dart';
import 'meeting_ir/meeting_ir_user_edits.dart';
import 'meeting_ir/meeting_ir_user_edits_store.dart';
import 'meeting_ir/meeting_ir_widgets.dart';
import 'whisper/api/meetings.dart' as rust;
import 'mind_service.dart';
import 'trust/scribe_trust_signals.dart';

/// Transcript and minutes — live, or reopened.
///
/// One screen for both because they are the same reading task at different
/// times: "watch processing" is reading the transcript early. A separate
/// progress screen would mean two layouts to keep in step and a jarring swap at
/// the moment the user is most attentive.
///
/// #1658 extends this screen (does not replace it) with Meeting-IR MoM
/// sections, checkable actions, evidence tracing, and user-edit overlays.
class MeetingScreen extends StatefulWidget {
  /// Live: the pipeline is running and this stream is producing it.
  const MeetingScreen.live({
    required this.service,
    required this.title,
    required Stream<MindProgress> this._progress,
    this.meetingIntelligenceEnabled = true,
    this.showLowTierCloudChoice = false,
    this.onCloudFallback,
    this.onSeekAudio,
    this.userEditsStore,
    super.key,
  }) : _meeting = null;

  /// Stored: reopened from the log.
  const MeetingScreen.stored({
    required this.service,
    required rust.MeetingRecord this._meeting,
    this.meetingIntelligenceEnabled = true,
    this.showLowTierCloudChoice = false,
    this.onCloudFallback,
    this.onSeekAudio,
    this.userEditsStore,
    super.key,
  }) : _progress = null,
       title = '';

  final MindService service;
  final String title;
  final Stream<MindProgress>? _progress;
  final rust.MeetingRecord? _meeting;

  /// Pro / launch-promo seam: when false, IR MoM review is locked (AC).
  /// Open-source builds leave this true (`LaunchPromoEntitlements`).
  final bool meetingIntelligenceEnabled;

  /// Device below LLM tier (#1658): show cloud-fallback choice, not a crash.
  final bool showLowTierCloudChoice;

  /// Invoked when the user picks cloud fallback from the low-tier banner.
  final VoidCallback? onCloudFallback;

  /// Optional audio seek when evidence is tapped (`startMs`). No player is
  /// wired in feature_mind yet — shells may supply one.
  final void Function(int startMs)? onSeekAudio;

  /// Override for tests. Defaults to a SharedPreferences-backed store.
  final MeetingIrUserEditsStore? userEditsStore;

  @override
  State<MeetingScreen> createState() => _MeetingScreenState();
}

class _MeetingScreenState extends State<MeetingScreen> {
  late MindProgress _progress;
  rust.MeetingRecord? _meeting;

  // #1663: markdown export. Constructed here rather than injected — like
  // `MindService`'s own defaults, the production path is the only path this
  // screen needs; a test exercises the service/gateway directly instead of
  // through the widget (see `test/export/`).
  late final _exportService = MeetingExportService(widget.service);
  final _exportGateway = const PlatformMeetingExportGateway();
  bool _exporting = false;

  late final MeetingIrUserEditsStore _editsStore =
      widget.userEditsStore ?? MeetingIrUserEditsStore();
  MeetingIrUserEdits _edits = const MeetingIrUserEdits();
  final _evidence = const EvidenceResolver();

  Map<String, TranscriptSegmentView> _segmentsById = const {};
  List<TranscriptSegmentView> _orderedSegments = const [];
  Set<String> _highlightedIds = const {};
  final Map<String, GlobalKey> _segmentKeys = {};
  String? _busyActionId;
  bool _dismissedLowTier = false;
  int? _pendingSeekMs;

  @override
  void initState() {
    super.initState();
    final stored = widget._meeting;
    _meeting = stored;
    _progress = stored == null
        ? const MindProgress(stage: MindStage.transcribing)
        : MindProgress(
            stage: MindStage.done,
            transcript: stored.transcript,
            minutes: stored.minutes,
            meetingId: stored.id,
          );
    widget._progress?.listen(
      (p) {
        if (mounted) {
          setState(() {
            _progress = p;
            _syncLiveSegments();
          });
          if (p.meetingId != null && _meeting == null) {
            _reloadMeeting(p.meetingId!);
          }
        }
      },
      // A stream error still has to reach the screen: silently ending on a
      // half-finished transcript is the failure that looks like a hang.
      onError: (Object e) {
        if (mounted) {
          setState(
            () => _progress = _progress.copyWith(
              stage: MindStage.failed,
              error: '$e',
            ),
          );
        }
      },
    );
    if (stored != null) {
      _loadIrContext(stored);
    } else {
      _syncLiveSegments();
    }
  }

  void _syncLiveSegments() {
    if (_progress.segments.isEmpty) return;
    _orderedSegments = [
      for (final s in _progress.segments)
        TranscriptSegmentView(
          id: s.id,
          startMs: s.startMs,
          endMs: s.endMs,
          text: s.text,
        ),
    ];
    _segmentsById = {for (final s in _orderedSegments) s.id: s};
    for (final s in _orderedSegments) {
      _segmentKeys.putIfAbsent(s.id, GlobalKey.new);
    }
  }

  Future<void> _loadIrContext(rust.MeetingRecord meeting) async {
    final edits = await _editsStore.load(meeting.id);
    final doc = await widget.service.transcriptDocument(meeting.id);
    final byId = _evidence.indexFromDocument(doc);
    final ordered = [
      for (final s in doc?.segments ?? const <rust.TranscriptSegmentRecord>[])
        TranscriptSegmentView(
          id: s.id,
          startMs: s.startMs.toInt(),
          endMs: s.endMs.toInt(),
          text: s.text,
        ),
    ];
    if (!mounted) return;
    setState(() {
      _edits = edits;
      _orderedSegments = ordered.isNotEmpty
          ? ordered
          : [
              // Flat transcript only — no segment ids to highlight against.
            ];
      _segmentsById = {
        for (final e in byId.entries)
          e.key: TranscriptSegmentView(
            id: e.value.id,
            startMs: e.value.startMs,
            endMs: e.value.endMs,
            text: e.value.text,
          ),
      };
      for (final s in _orderedSegments) {
        _segmentKeys.putIfAbsent(s.id, GlobalKey.new);
      }
    });
  }

  Future<void> _reloadMeeting(String id) async {
    final meeting = await widget.service.meeting(id);
    if (meeting == null || !mounted) return;
    setState(() => _meeting = meeting);
    await _loadIrContext(meeting);
  }

  bool get _isRunning =>
      _progress.stage == MindStage.transcribing ||
      _progress.stage == MindStage.generating ||
      _progress.stage == MindStage.saving;

  /// Exports the stored meeting as markdown, then either hands it to the
  /// share sheet or writes it to a folder the user picks. A no-op for a live
  /// (not-yet-saved) meeting — there is no [MeetingScreen.stored]'s
  /// `_meeting.id` to export until the pipeline finishes.
  Future<void> _export({required bool share}) async {
    final meetingId = _meeting?.id ?? _progress.meetingId;
    if (meetingId == null || _exporting) return;

    setState(() => _exporting = true);
    try {
      final bundle = await _exportService.exportMeeting(meetingId);
      if (bundle == null) {
        _notify('That meeting could not be found.');
        return;
      }
      final ok = share
          ? await _exportGateway.share([bundle])
          : await _exportGateway.saveToFolder([bundle]);
      if (ok) {
        _notify(share ? 'Shared as markdown.' : 'Saved as markdown.');
      }
    } on Object catch (e) {
      _notify('Export failed: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String get _stageLabel => switch (_progress.stage) {
    MindStage.transcribing => 'Transcribing…',
    MindStage.generating => 'Extracting…',
    MindStage.saving => 'Saving…',
    MindStage.done => 'Ready',
    MindStage.failed => 'Failed',
    _ => '',
  };

  void _onEvidence(List<String> evidenceSegmentIds) {
    final hits = _evidence.resolve(
      evidenceSegmentIds: evidenceSegmentIds,
      byId: {
        for (final e in _segmentsById.entries)
          e.key: TranscriptSegment(
            id: e.value.id,
            startMs: e.value.startMs,
            endMs: e.value.endMs,
            text: e.value.text,
          ),
      },
    );
    final ids = {for (final h in hits) h.segmentId};
    final seekMs = hits.isEmpty ? null : hits.first.startMs;
    setState(() {
      _highlightedIds = ids;
      _pendingSeekMs = seekMs;
    });
    if (seekMs != null) {
      widget.onSeekAudio?.call(seekMs);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ids.isEmpty) return;
      final key = _segmentKeys[ids.first];
      final ctx = key?.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 280),
          alignment: 0.2,
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _toggleAction(rust.MeetingActionItemRecord item) async {
    final meeting = _meeting;
    if (meeting == null || _busyActionId != null) return;
    final next = item.status == rust.MeetingActionStatus.done
        ? rust.MeetingActionStatus.open
        : rust.MeetingActionStatus.done;
    setState(() => _busyActionId = item.id);
    try {
      final updated = await widget.service.updateActionItemStatus(
        meeting: meeting,
        actionItemId: item.id,
        status: next,
      );
      if (!mounted) return;
      setState(() {
        _meeting = updated;
        _busyActionId = null;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() => _busyActionId = null);
      _notify('Could not update action: $e');
    }
  }

  Future<void> _editAction(rust.MeetingActionItemRecord item) async {
    final meeting = _meeting;
    if (meeting == null) return;
    final taskController = TextEditingController(text: _edits.taskFor(item));
    final ownerController = TextEditingController(
      text: _edits.ownerFor(item) ?? item.owner ?? '',
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit action'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('meeting_ir_edit_task'),
              controller: taskController,
              decoration: const InputDecoration(labelText: 'Task'),
              maxLines: 3,
            ),
            TextField(
              key: const Key('meeting_ir_edit_owner'),
              controller: ownerController,
              decoration: const InputDecoration(labelText: 'Owner'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('meeting_ir_edit_save'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved != true || !mounted) {
      taskController.dispose();
      ownerController.dispose();
      return;
    }
    final next = await _editsStore.upsert(
      meetingId: meeting.id,
      actionId: item.id,
      edit: MeetingActionUserEdit(
        task: taskController.text.trim().isEmpty
            ? item.task
            : taskController.text.trim(),
        owner: ownerController.text.trim(),
      ),
    );
    taskController.dispose();
    ownerController.dispose();
    if (!mounted) return;
    setState(() => _edits = next);
  }

  @override
  Widget build(BuildContext context) {
    final stored = _meeting ?? widget._meeting;
    final hasIr =
        stored != null &&
        (stored.decisions.isNotEmpty ||
            stored.actionItems.isNotEmpty ||
            stored.metrics.isNotEmpty);
    final showMinutesFallback =
        _progress.minutes.isNotEmpty &&
        (!hasIr || !widget.meetingIntelligenceEnabled);

    return Scaffold(
      appBar: AppBar(
        title: Text(stored?.title ?? widget.title),
        actions: [
          if (_isRunning)
            TextButton(
              onPressed: () {
                widget.service.cancelProcessing();
                Navigator.of(context).pop();
              },
              child: const Text('Stop'),
            )
          // Export needs a saved meeting id -- available once processing
          // reaches `done`, or always for a reopened meeting.
          else if (stored != null || _progress.meetingId != null)
            PopupMenuButton<bool>(
              icon: _exporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.ios_share),
              tooltip: 'Export as markdown',
              onSelected: (share) => _export(share: share),
              itemBuilder: (_) => const [
                PopupMenuItem(value: false, child: Text('Save to folder')),
                PopupMenuItem(value: true, child: Text('Share')),
              ],
            ),
        ],
      ),
      // ResponsiveStandards: constrain reading width on tablet/desktop.
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ScribeTrustSignals(state: widget.service.scribeTrustState()),
              const SizedBox(height: 12),
              if (_isRunning) const LinearProgressIndicator(),
              if (_stageLabel.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    _stageLabel,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              if (widget.showLowTierCloudChoice && !_dismissedLowTier) ...[
                MeetingIrLowTierBanner(
                  onUseCloud: () {
                    widget.onCloudFallback?.call();
                    setState(() => _dismissedLowTier = true);
                  },
                  onStayLocal: () => setState(() => _dismissedLowTier = true),
                ),
                const SizedBox(height: 16),
              ],
              if (_progress.error != null)
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(_progress.error!),
                  ),
                ),
              if (!widget.meetingIntelligenceEnabled && stored != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: AiroSurface(
                    level: AiroSurfaceLevel.raised,
                    child: Text(
                      'Meeting intelligence is a Pro feature on this build.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
              if (widget.meetingIntelligenceEnabled && stored != null)
                MeetingIrMomSections(
                  decisions: stored.decisions,
                  actionItems: stored.actionItems,
                  metrics: stored.metrics,
                  edits: _edits,
                  segmentsById: _segmentsById,
                  busyActionId: _busyActionId,
                  onEvidence: _onEvidence,
                  onToggleAction: _toggleAction,
                  onEditAction: _editAction,
                  formatClock: formatEvidenceClock,
                ),
              if (showMinutesFallback) ...[
                const _SectionTitle('Minutes'),
                SelectableText(_progress.minutes.trim()),
                const SizedBox(height: 24),
              ],
              if (_progress.transcript.isNotEmpty ||
                  _orderedSegments.isNotEmpty) ...[
                const _SectionTitle('Transcript'),
                if (_pendingSeekMs != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Evidence at ${formatEvidenceClock(_pendingSeekMs!)}',
                      key: const Key('meeting_ir_evidence_clock'),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                MeetingIrTranscriptList(
                  segments: _orderedSegments,
                  highlightedIds: _highlightedIds,
                  segmentKeys: _segmentKeys,
                  fallbackTranscript: _progress.transcript,
                ),
              ],
              if (stored != null) ...[
                const SizedBox(height: 24),
                // Which model wrote the minutes, per ADR-0018. Shown rather than
                // stored-and-hidden: a summary is a model's reading of a meeting,
                // and the user is entitled to know whose reading it was.
                Text(
                  'Minutes by ${stored.model}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// `mm:ss` for the evidence clock chip (shorter than export's `[hh:mm:ss]`).
String formatEvidenceClock(int ms) {
  final totalSeconds = ms ~/ 1000;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}
