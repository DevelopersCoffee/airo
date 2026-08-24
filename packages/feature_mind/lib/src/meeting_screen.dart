import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import 'bridges/mind_speech_bridge.dart' show TranscriptSegment;
import 'export/application/meeting_export_service.dart';
import 'export/application/meeting_share_port.dart';
import 'export/data/meeting_export_gateway.dart';
import 'export/domain/meeting_export_models.dart';
import 'export/domain/meeting_markdown_renderer.dart';
import 'meeting_audio/meeting_audio_bar.dart';
import 'meeting_audio/meeting_audio_playback.dart';
import 'meeting_ir/evidence_resolver.dart';
import 'meeting_ir/meeting_ir_user_edits.dart';
import 'meeting_ir/meeting_ir_user_edits_store.dart';
import 'meeting_ir/meeting_ir_widgets.dart';
import 'meeting_ir/meeting_minutes_content.dart';
import 'speaker/meeting_speaker_registry.dart';
import 'speaker/meeting_speaker_registry_store.dart';
import 'speaker/global_speaker_enrollment_store.dart';
import 'speaker/speaker_rename_dialog.dart';
import 'speaker/speaker_remember_dialog.dart';
import 'whisper/api/meetings.dart' as rust;
import 'mind_diarization.dart';
import 'mind_service.dart';
import 'processing/application/transcript_quality_evaluator.dart';
import 'processing/presentation/transcript_review_banner.dart';
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
    this.audioPath,
    this.meetingIntelligenceEnabled = true,
    this.showLowTierCloudChoice = false,
    this.onCloudFallback,
    this.onSeekAudio,
    this.userEditsStore,
    this.speakerRegistryStore,
    this.audioPlayback,
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
    this.speakerRegistryStore,
    this.audioPlayback,
    super.key,
  }) : _progress = null,
       title = '',
       audioPath = null;

  final MindService service;
  final String title;
  final Stream<MindProgress>? _progress;
  final rust.MeetingRecord? _meeting;

  /// Recording path while [MindService.process] is running — enables speaker
  /// enrollment before the transcript document is saved (#504).
  final String? audioPath;

  /// Pro / launch-promo seam: when false, IR MoM review is locked (AC).
  /// Open-source builds leave this true (`LaunchPromoEntitlements`).
  final bool meetingIntelligenceEnabled;

  /// Device below LLM tier (#1658): show cloud-fallback choice, not a crash.
  final bool showLowTierCloudChoice;

  /// Invoked when the user picks cloud fallback from the low-tier banner.
  final VoidCallback? onCloudFallback;

  /// Optional extra seek hook when evidence or a transcript line is tapped.
  /// The screen also plays the kept recording itself when the file is still
  /// on disk.
  final void Function(int startMs)? onSeekAudio;

  /// Injected player for tests. Production constructs one in state.
  final MeetingAudioPlayback? audioPlayback;

  /// Override for tests. Defaults to a SharedPreferences-backed store.
  final MeetingIrUserEditsStore? userEditsStore;

  /// Per-meeting speaker rename / merge overlays.
  final MeetingSpeakerRegistryStore? speakerRegistryStore;

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
  late final MeetingIrUserEditsStore _editsStore =
      widget.userEditsStore ?? MeetingIrUserEditsStore();
  late final MeetingSpeakerRegistryStore _speakerStore =
      widget.speakerRegistryStore ?? MeetingSpeakerRegistryStore();
  final _globalEnrollmentStore = GlobalSpeakerEnrollmentStore();
  late final _exportService = MeetingExportService(
    widget.service,
    speakerRegistryStore: _speakerStore,
  );
  final _exportGateway = const PlatformMeetingExportGateway();
  final _sharePort = const PlatformMeetingSharePort();
  bool _exporting = false;

  MeetingIrUserEdits _edits = const MeetingIrUserEdits();
  MeetingSpeakerRegistry _speakerRegistry = MeetingSpeakerRegistry.empty;
  List<GlobalEnrolledSpeaker> _globalProfiles = const [];
  String? _audioPath;
  final _evidence = const EvidenceResolver();

  Map<String, TranscriptSegmentView> _segmentsById = const {};
  List<TranscriptSegmentView> _orderedSegments = const [];
  Set<String> _highlightedIds = const {};
  final Map<String, GlobalKey> _segmentKeys = {};
  String? _busyActionId;
  bool _dismissedLowTier = false;
  int? _pendingSeekMs;
  bool _regenerating = false;
  MeetingTranscriptQualityReport? _qualityReport;
  late final MeetingAudioPlayback _playback;

  @override
  void initState() {
    super.initState();
    _playback = widget.audioPlayback ?? MeetingAudioPlayback();
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
            if (p.qualityReport != null) {
              _qualityReport = p.qualityReport;
            }
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
      unawaited(_loadQualityReport(stored.id));
    } else {
      _syncLiveSegments();
      _audioPath = widget.audioPath;
    }
    _loadGlobalEnrollment();
  }

  @override
  void dispose() {
    if (widget.audioPlayback == null) {
      _playback.dispose();
    }
    super.dispose();
  }

  bool get _hasAudio => MeetingAudioPlayback.fileExists(_audioPath);

  Future<void> _loadGlobalEnrollment() async {
    final profiles = await _globalEnrollmentStore.loadProfiles();
    if (!mounted) return;
    setState(() => _globalProfiles = profiles);
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
          speakerLabel: s.speakerLabel,
        ),
    ];
    _segmentsById = {for (final s in _orderedSegments) s.id: s};
    for (final s in _orderedSegments) {
      _segmentKeys.putIfAbsent(s.id, GlobalKey.new);
    }
  }

  Future<void> _loadIrContext(rust.MeetingRecord meeting) async {
    final edits = await _editsStore.load(meeting.id);
    final speakers = await _speakerStore.load(meeting.id);
    final doc = await widget.service.transcriptDocument(meeting.id);
    final byId = _evidence.indexFromDocument(doc);
    final ordered = [
      for (final s in doc?.segments ?? const <rust.TranscriptSegmentRecord>[])
        TranscriptSegmentView(
          id: s.id,
          startMs: s.startMs.toInt(),
          endMs: s.endMs.toInt(),
          text: s.text,
          speakerLabel: s.speakerLabel,
        ),
    ];
    if (!mounted) return;
    setState(() {
      _edits = edits;
      _speakerRegistry = speakers;
      _audioPath = doc?.audioPath;
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
            speakerLabel: e.value.speakerLabel,
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
    await _loadQualityReport(id);
  }

  Future<void> _loadQualityReport(String meetingId) async {
    final report = await widget.service.transcriptQualityReport(meetingId);
    if (!mounted) return;
    setState(() => _qualityReport = report);
  }

  MeetingTranscriptQualityReport? get _activeQualityReport =>
      _qualityReport ?? _progress.qualityReport;

  bool get _isRunning =>
      _progress.stage == MindStage.transcribing ||
      _progress.stage == MindStage.extracting ||
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

  String? get _meetingId => _meeting?.id ?? _progress.meetingId;

  String get _displayTitle =>
      _meeting?.title.trim().isNotEmpty == true
          ? _meeting!.title
          : widget.title;

  Map<String, String> get _globalEnrolledNames =>
      globalEnrolledSpeakerNames(_globalProfiles);

  List<TranscriptExportLine> get _exportLines => [
    for (final segment in _orderedSegments)
      TranscriptExportLine(
        startMs: segment.startMs,
        text: segment.text,
        speakerLabel: segment.speakerLabel,
      ),
  ];

  String _plainTranscriptText() => renderTranscriptPlainText(
    lines: _exportLines,
    fallbackTranscript: _progress.transcript,
    speakerRegistry: _speakerRegistry,
    globalEnrolledNames: _globalEnrolledNames,
    applyPersonaNames: _applySpeakerPersonaNames,
  );

  String? _plainMinutesText() {
    final minutes = (_meeting?.minutes ?? _progress.minutes).trim();
    if (minutes.isEmpty || isEmptyMeetingMinutes(minutes)) return null;
    return minutes;
  }

  bool get _soloDiarizationHint {
    if (_orderedSegments.length < 2) return false;
    return !mindShouldApplySpeakerPersonaNames(
      _orderedSegments.map((segment) => segment.speakerLabel),
    );
  }

  bool get _applySpeakerPersonaNames => mindShouldApplySpeakerPersonaNames(
    _orderedSegments.map((segment) => segment.speakerLabel),
  );

  Future<void> _copyTranscript() async {
    final text = _plainTranscriptText();
    if (text.isEmpty) {
      _notify('No transcript to copy.');
      return;
    }
    await _sharePort.copyText(text);
    _notify('Transcript copied.');
  }

  Future<void> _copyMinutes() async {
    final minutes = _plainMinutesText();
    if (minutes == null) {
      _notify('No minutes to copy.');
      return;
    }
    await _sharePort.copyText(minutes);
    _notify('Minutes copied.');
  }

  Future<void> _shareRecording() async {
    final path = _audioPath;
    if (!MeetingAudioPlayback.fileExists(path)) {
      _notify('Recording file is not available.');
      return;
    }
    final ok = await _sharePort.shareFiles(
      [path!],
      subject: _displayTitle,
    );
    if (ok) {
      _notify('Shared recording.');
    }
  }

  Future<void> _shareTranscriptMarkdown() async {
    final meetingId = _meetingId;
    if (meetingId == null || _exporting) return;
    setState(() => _exporting = true);
    try {
      final bundle = await _exportService.exportMeeting(meetingId);
      final markdown = bundle == null
          ? null
          : transcriptMarkdownFromBundle(bundle);
      if (markdown == null || markdown.isEmpty) {
        _notify('No transcript to share.');
        return;
      }
      final ok = await _sharePort.shareMarkdown(
        filename: '${bundle!.folderName}-transcript.md',
        markdown: markdown,
        subject: '$_displayTitle — transcript',
      );
      if (ok) _notify('Shared transcript.');
    } on Object catch (e) {
      _notify('Share failed: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _shareMinutesMarkdown() async {
    final meetingId = _meetingId;
    if (meetingId == null || _exporting) return;
    setState(() => _exporting = true);
    try {
      final bundle = await _exportService.exportMeeting(meetingId);
      final markdown = bundle == null
          ? null
          : minutesMarkdownFromBundle(bundle);
      if (markdown == null || markdown.isEmpty) {
        _notify('No minutes to share.');
        return;
      }
      final ok = await _sharePort.shareMarkdown(
        filename: '${bundle!.folderName}-mom.md',
        markdown: markdown,
        subject: '$_displayTitle — minutes',
      );
      if (ok) _notify('Shared minutes.');
    } on Object catch (e) {
      _notify('Share failed: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _onShareMenuSelected(String value) {
    switch (value) {
      case 'copy_transcript':
        unawaited(_copyTranscript());
      case 'copy_minutes':
        unawaited(_copyMinutes());
      case 'share_recording':
        unawaited(_shareRecording());
      case 'share_transcript':
        unawaited(_shareTranscriptMarkdown());
      case 'share_minutes':
        unawaited(_shareMinutesMarkdown());
      case 'save':
        unawaited(_export(share: false));
      case 'share_all':
        unawaited(_export(share: true));
      case 'regenerate':
        unawaited(_regenerate());
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
    MindStage.extracting => 'Extracting…',
    MindStage.generating => 'Generating minutes…',
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
      final path = _audioPath;
      if (MeetingAudioPlayback.fileExists(path)) {
        unawaited(_playback.seekAndPlay(path!, seekMs));
      }
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

  void _onTranscriptTap(TranscriptSegmentView segment) {
    _onEvidence([segment.id]);
  }

  Future<void> _regenerate() async {
    final meeting = _meeting;
    final path = _audioPath;
    if (meeting == null || !MeetingAudioPlayback.fileExists(path)) {
      _notify('Recording is not on this device.');
      return;
    }
    if (_regenerating || _isRunning) return;
    setState(() => _regenerating = true);
    final recordedAtMs =
        int.tryParse(
          meeting.id.startsWith('m') ? meeting.id.substring(1) : '',
        ) ??
        meeting.recordedAt.toInt() * 1000;
    try {
      await for (final progress in widget.service.process(
        wavPath: path!,
        title: meeting.title,
        recordedAtMs: recordedAtMs,
      )) {
        if (!mounted) return;
        setState(() => _progress = progress);
      }
      if (!mounted) return;
      await _reloadMeeting(meeting.id);
      await _loadQualityReport(meeting.id);
    } on Object catch (e) {
      if (mounted) _notify('Could not regenerate: $e');
    } finally {
      if (mounted) setState(() => _regenerating = false);
    }
  }

  Future<void> _renameSpeaker(String speakerLabel) async {
    final meetingId = _meeting?.id ?? _progress.meetingId;
    if (meetingId == null) return;
    final name = await showSpeakerRenameDialog(
      context: context,
      speakerLabel: speakerLabel,
      registry: _speakerRegistry,
    );
    if (name == null || !mounted) return;
    final next = _speakerRegistry.renameSpeaker(
      label: speakerLabel,
      displayName: name,
    );
    await _speakerStore.save(meetingId, next);
    if (!mounted) return;
    setState(() => _speakerRegistry = next);
  }

  Future<void> _mergeSpeaker(String fromLabel) async {
    final meetingId = _meeting?.id ?? _progress.meetingId;
    if (meetingId == null) return;
    final labels = {
      for (final segment in _orderedSegments)
        if (segment.speakerLabel != null)
          _speakerRegistry.canonicalLabel(segment.speakerLabel!),
    }.toList();
    final into = await showSpeakerMergeDialog(
      context: context,
      fromLabel: fromLabel,
      candidateLabels: labels,
      registry: _speakerRegistry,
    );
    if (into == null || !mounted) return;
    final next = _speakerRegistry.mergeSpeakers(
      fromLabel: fromLabel,
      intoLabel: into,
    );
    await _speakerStore.save(meetingId, next);
    if (!mounted) return;
    setState(() => _speakerRegistry = next);
  }

  TranscriptSegmentView? _segmentForSpeaker(String speakerLabel) {
    final canonical = _speakerRegistry.canonicalLabel(speakerLabel);
    for (final segment in _orderedSegments) {
      final label = segment.speakerLabel;
      if (label != null &&
          _speakerRegistry.canonicalLabel(label) == canonical) {
        return segment;
      }
    }
    return null;
  }

  Future<void> _rememberSpeaker(String speakerLabel) async {
    final audioPath = _audioPath;
    if (audioPath == null || audioPath.isEmpty) {
      _notify('Audio is not available yet for speaker enrollment.');
      return;
    }
    final segment = _segmentForSpeaker(speakerLabel);
    if (segment == null) {
      _notify('No transcript segment found for this speaker.');
      return;
    }
    final name = await showSpeakerRememberDialog(
      context: context,
      speakerLabel: speakerLabel,
      registry: _speakerRegistry,
    );
    if (name == null || !mounted) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final profile = await _globalEnrollmentStore.enrollFromSegment(
      displayName: trimmed,
      wavPath: audioPath,
      startMs: segment.startMs,
      endMs: segment.endMs,
    );
    if (!mounted) return;
    if (profile == null) {
      _notify('Could not compute a voice profile for this segment.');
      return;
    }
    final meetingId = _meeting?.id ?? _progress.meetingId;
    if (meetingId != null) {
      final next = _speakerRegistry.renameSpeaker(
        label: speakerLabel,
        displayName: profile.displayName,
      );
      await _speakerStore.save(meetingId, next);
      if (mounted) setState(() => _speakerRegistry = next);
    }
    await _loadGlobalEnrollment();
    if (!mounted) return;
    _notify('Remembered ${profile.displayName} for future meetings.');
  }

  @override
  Widget build(BuildContext context) {
    final stored = _meeting ?? widget._meeting;
    final hasIr =
        stored != null &&
        (stored.decisions.isNotEmpty ||
            stored.actionItems.isNotEmpty ||
            stored.metrics.isNotEmpty);
    final minutes = _progress.minutes.trim();
    final showMinutesFallback =
        minutes.isNotEmpty &&
        !isEmptyMeetingMinutes(minutes) &&
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
            PopupMenuButton<String>(
              icon: _exporting || _regenerating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.more_vert),
              tooltip: 'Share and export',
              onSelected: _onShareMenuSelected,
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'copy_transcript',
                  child: Text('Copy transcript'),
                ),
                if (_plainMinutesText() != null)
                  const PopupMenuItem(
                    value: 'copy_minutes',
                    child: Text('Copy minutes'),
                  ),
                if (_hasAudio)
                  const PopupMenuItem(
                    value: 'share_recording',
                    child: Text('Share recording'),
                  ),
                const PopupMenuItem(
                  value: 'share_transcript',
                  child: Text('Share transcript'),
                ),
                if (_plainMinutesText() != null)
                  const PopupMenuItem(
                    value: 'share_minutes',
                    child: Text('Share minutes'),
                  ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'share_all',
                  child: Text('Share all (markdown)'),
                ),
                const PopupMenuItem(
                  value: 'save',
                  child: Text('Save to folder'),
                ),
                if (_hasAudio)
                  const PopupMenuItem(
                    value: 'regenerate',
                    child: Text('Re-transcribe (speakers + minutes)'),
                  ),
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
              if (_activeQualityReport != null) ...[
                const SizedBox(height: 12),
                TranscriptReviewBanner(report: _activeQualityReport!),
              ],
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
              if (_hasAudio) ...[
                MeetingAudioBar(playback: _playback, audioPath: _audioPath!),
                const SizedBox(height: 12),
              ],
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
                if (_soloDiarizationHint)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Speaker labels show as one voice. Open ⋯ → Re-transcribe '
                      'to refresh diarization, or rename speakers manually.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
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
                  speakerRegistry: _speakerRegistry,
                  onRenameSpeaker: _renameSpeaker,
                  onMergeSpeaker: _mergeSpeaker,
                  onRememberSpeaker: _audioPath != null
                      ? _rememberSpeaker
                      : null,
                  onSegmentTap: _onTranscriptTap,
                  globalEnrolledNames: globalEnrolledSpeakerNames(
                    _globalProfiles,
                  ),
                  applyPersonaNames: _applySpeakerPersonaNames,
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
