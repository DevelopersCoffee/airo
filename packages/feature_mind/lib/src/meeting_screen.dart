import 'package:flutter/material.dart';

import 'export/application/meeting_export_service.dart';
import 'export/data/meeting_export_gateway.dart';
import 'whisper/api/meetings.dart' as rust;
import 'mind_service.dart';
import 'trust/scribe_trust_signals.dart';

/// Transcript and minutes — live, or reopened.
///
/// One screen for both because they are the same reading task at different
/// times: "watch processing" is reading the transcript early. A separate
/// progress screen would mean two layouts to keep in step and a jarring swap at
/// the moment the user is most attentive.
class MeetingScreen extends StatefulWidget {
  /// Live: the pipeline is running and this stream is producing it.
  const MeetingScreen.live({
    required this.service,
    required this.title,
    required Stream<MindProgress> this._progress,
    super.key,
  }) : _meeting = null;

  /// Stored: reopened from the log.
  const MeetingScreen.stored({
    required this.service,
    required rust.MeetingRecord this._meeting,
    super.key,
  }) : _progress = null,
       title = '';

  final MindService service;
  final String title;
  final Stream<MindProgress>? _progress;
  final rust.MeetingRecord? _meeting;

  @override
  State<MeetingScreen> createState() => _MeetingScreenState();
}

class _MeetingScreenState extends State<MeetingScreen> {
  late MindProgress _progress;

  // #1663: markdown export. Constructed here rather than injected — like
  // `MindService`'s own defaults, the production path is the only path this
  // screen needs; a test exercises the service/gateway directly instead of
  // through the widget (see `test/export/`).
  late final _exportService = MeetingExportService(widget.service);
  final _exportGateway = const PlatformMeetingExportGateway();
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    final stored = widget._meeting;
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
        if (mounted) setState(() => _progress = p);
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
    final meetingId = widget._meeting?.id ?? _progress.meetingId;
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
    MindStage.generating => 'Writing minutes…',
    MindStage.saving => 'Saving…',
    MindStage.done => 'Saved on this device',
    MindStage.failed => 'Failed',
    _ => '',
  };

  @override
  Widget build(BuildContext context) {
    final stored = widget._meeting;
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ScribeTrustSignals(
            state: widget.service.scribeTrustState(),
          ),
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
          if (_progress.error != null)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_progress.error!),
              ),
            ),
          if (_progress.minutes.isNotEmpty) ...[
            const _SectionTitle('Minutes'),
            SelectableText(_progress.minutes.trim()),
            const SizedBox(height: 24),
          ],
          if (_progress.transcript.isNotEmpty) ...[
            const _SectionTitle('Transcript'),
            SelectableText(_progress.transcript.trim()),
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
    );
  }
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
