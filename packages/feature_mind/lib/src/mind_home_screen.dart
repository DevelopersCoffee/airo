import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'whisper/api/meetings.dart' as rust;
import 'capture/application/speech_language_preference.dart';
import 'export/application/meeting_export_service.dart';
import 'export/data/meeting_export_gateway.dart';
import 'meeting_screen.dart';
import 'mind_service.dart';
import 'models/model_provider.dart';
import 'trust/scribe_trust_signals.dart';

/// The whole app. Record, search, open.
///
/// One screen because the milestone is one journey. No themes, no settings, no
/// personalization — those are choices to make once the journey is proven, not
/// while proving it.
class MindHomeScreen extends StatefulWidget {
  const MindHomeScreen({required this.service, super.key});

  final MindService service;

  @override
  State<MindHomeScreen> createState() => _MindHomeScreenState();
}

class _MindHomeScreenState extends State<MindHomeScreen> {
  final _query = TextEditingController();

  // #1663: batch markdown export of every meeting currently listed.
  late final _exportService = MeetingExportService(widget.service);
  final _exportGateway = const PlatformMeetingExportGateway();
  bool _exportingAll = false;

  MindStatus? _status;
  List<rust.MeetingRecord> _meetings = const [];
  List<rust.SearchHit>? _hits;
  bool _recording = false;
  String? _error;

  /// The file currently being fetched, and how far. First run is now a
  /// download rather than an asset copy
  /// (`docs/superpowers/specs/2026-08-07-airo-mind-abstraction-layer.md`), and
  /// ~570 MB with nothing on screen reads as a hang, not progress.
  String? _downloadingFile;
  int _downloadedBytes = 0;
  int _downloadTotalBytes = 0;

  @override
  void initState() {
    super.initState();
    widget.service.onInstallProgress = (fileName, copied, total) {
      if (!mounted) return;
      setState(() {
        _downloadingFile = fileName;
        _downloadedBytes = copied;
        _downloadTotalBytes = total;
      });
    };
    _start();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final mode = await loadSpeechLanguageMode();
    final status = await widget.service.initialize(
      speechLanguage: mode.speechLanguage,
    );
    if (!mounted) return;
    setState(() {
      _status = status;
      // Whatever the outcome, the download phase (if there was one) is over.
      _downloadingFile = null;
    });
    if (status.isReady) await _refresh();
  }

  /// Re-runs startup from scratch, back through the loading state. Used after
  /// the models arrive: the previous status is stale the moment they do, and
  /// leaving it on screen while the engines load reads as "nothing happened".
  Future<void> _restart() async {
    setState(() => _status = null);
    await _start();
  }

  Future<void> _refresh() async {
    try {
      final meetings = await widget.service.meetings();
      if (mounted) setState(() => _meetings = meetings);
    } on Object catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _hits = null);
      return;
    }
    final hits = await widget.service.search(query);
    if (mounted) setState(() => _hits = hits);
  }

  Future<void> _toggleRecording() async {
    if (_recording) {
      final path = await widget.service.stopRecording();
      if (!mounted) return;
      setState(() => _recording = false);
      if (path == null) return;

      final title = 'Meeting ${_meetings.length + 1}';
      final mode = await loadSpeechLanguageMode();
      if (!mounted) return;
      final progress = widget.service.process(
        wavPath: path,
        title: title,
        language: mode.processLanguageCode,
      );
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MeetingScreen.live(
            service: widget.service,
            title: title,
            progress: progress,
          ),
        ),
      );
      // The user came back — the meeting may now exist, or may have been
      // cancelled. Re-reading the store is the only honest way to know.
      await _refresh();
      return;
    }

    if (!await widget.service.hasMicrophonePermission()) {
      if (mounted) {
        setState(() => _error = 'Airo Mind needs microphone access to record.');
      }
      return;
    }
    await widget.service.startRecording();
    if (mounted) setState(() => _recording = true);
  }

  /// Exports every meeting in [_meetings] as markdown in one action (#1663
  /// batch export). Shares rather than saves-to-folder by default — the
  /// share sheet is one prompt regardless of how many meetings are in the
  /// batch, where a folder picker still needs the caller to have somewhere
  /// in mind to put it. Long-pressing offers the folder instead.
  Future<void> _exportAll({required bool share}) async {
    if (_meetings.isEmpty || _exportingAll) return;
    setState(() => _exportingAll = true);
    try {
      final bundles = await _exportService.exportMeetings(
        _meetings.map((m) => m.id).toList(),
      );
      if (bundles.isEmpty) return;
      final ok = share
          ? await _exportGateway.share(bundles)
          : await _exportGateway.saveToFolder(bundles);
      if (ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              share
                  ? 'Shared ${bundles.length} meetings as markdown.'
                  : 'Saved ${bundles.length} meetings as markdown.',
            ),
          ),
        );
      }
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _exportingAll = false);
    }
  }

  Future<void> _open(String id) async {
    final meeting = await widget.service.meeting(id);
    if (!mounted || meeting == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            MeetingScreen.stored(service: widget.service, meeting: meeting),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Airo Mind'),
        actions: [
          if (status != null && status.isReady)
            IconButton(
              key: const Key('mind_home_record_meeting_button'),
              tooltip: 'Record a meeting',
              icon: const Icon(Icons.mic_none),
              onPressed: () => context.push('/record'),
            ),
          if (status != null && status.isReady && _meetings.isNotEmpty)
            PopupMenuButton<bool>(
              icon: _exportingAll
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.ios_share),
              tooltip: 'Export all as markdown',
              onSelected: (share) => _exportAll(share: share),
              itemBuilder: (_) => const [
                PopupMenuItem(value: true, child: Text('Share all')),
                PopupMenuItem(value: false, child: Text('Save all to folder')),
              ],
            ),
        ],
      ),
      body: switch (status) {
        // Startup. A provider that installs on its own (the bundled copy, or
        // a resumed download) reports through `onInstallProgress`, and
        // [_Loading] falls back to a bare spinner when there is no file in
        // flight — ~570 MB with nothing on screen reads as a hang (#1553).
        null => _Loading(
          fileName: _downloadingFile,
          downloadedBytes: _downloadedBytes,
          totalBytes: _downloadTotalBytes,
        ),
        // Models missing is the one blocker the user can clear from here, and
        // only when the provider fetches them — a build that bundles its
        // models and still reports them missing has nothing to offer but the
        // explanation (#1554).
        MindStatus(unavailable: MindUnavailable.modelsMissing)
            when widget.service.modelsNeedDownload =>
          _ModelDownload(service: widget.service, onInstalled: _restart),
        MindStatus(isReady: false) => _Unavailable(status: status),
        _ => _library(context),
      },
      floatingActionButton: status != null && status.isReady
          ? FloatingActionButton.extended(
              onPressed: _toggleRecording,
              icon: Icon(_recording ? Icons.stop : Icons.mic),
              label: Text(_recording ? 'Stop' : 'Record'),
            )
          : null,
    );
  }

  Widget _library(BuildContext context) {
    final hits = _hits;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: ScribeTrustSignals(state: widget.service.scribeTrustState()),
        ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _query,
            onChanged: _search,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search meetings',
              border: const OutlineInputBorder(),
              suffixIcon: _query.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _query.clear();
                        _search('');
                      },
                    ),
            ),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (_recording)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.fiber_manual_record, color: Colors.red, size: 14),
                SizedBox(width: 8),
                Text('Recording'),
              ],
            ),
          ),
        Expanded(
          child: hits != null
              ? _hitList(hits)
              : _meetingList(context, _meetings),
        ),
      ],
    );
  }

  Widget _hitList(List<rust.SearchHit> hits) {
    if (hits.isEmpty) {
      return const _Empty('No meeting mentions that.');
    }
    return ListView.builder(
      itemCount: hits.length,
      itemBuilder: (_, i) {
        final hit = hits[i];
        return ListTile(
          title: Text(hit.title),
          // The line that matched, so the user can see WHY before opening.
          subtitle: Text(
            hit.snippet,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => _open(hit.meetingId),
        );
      },
    );
  }

  Widget _meetingList(BuildContext context, List<rust.MeetingRecord> meetings) {
    if (meetings.isEmpty) {
      return const _Empty('No meetings yet. Press Record to start one.');
    }
    return ListView.builder(
      itemCount: meetings.length,
      itemBuilder: (_, i) {
        final m = meetings[i];
        return ListTile(
          title: Text(m.title),
          subtitle: Text(
            meetingListPreview(m),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => _open(m.id),
        );
      },
    );
  }
}

/// Cheap list subtitle: minutes first, else first action/decision text, else
/// transcript. Keeps IR discoverable without an extra store round-trip.
@visibleForTesting
String meetingListPreview(rust.MeetingRecord meeting) {
  final minutes = meeting.minutes.trim();
  if (minutes.isNotEmpty) return minutes;

  if (meeting.actionItems.isNotEmpty) {
    final item = meeting.actionItems.first;
    final owner = item.owner?.trim();
    return owner == null || owner.isEmpty ? item.task : '${item.task} — $owner';
  }
  if (meeting.decisions.isNotEmpty) {
    return meeting.decisions.first.statement;
  }
  return meeting.transcript;
}

/// Shown while [MindService.initialize] is in flight. Nothing to show yet
/// (native library load, or a model already on disk) falls back to a bare
/// spinner; a download in progress gets its own file name and percentage,
/// because ~570 MB with no feedback reads as a hang, not progress.
class _Loading extends StatelessWidget {
  const _Loading({
    required this.fileName,
    required this.downloadedBytes,
    required this.totalBytes,
  });

  final String? fileName;
  final int downloadedBytes;
  final int totalBytes;

  @override
  Widget build(BuildContext context) {
    final name = fileName;
    if (name == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final fraction = totalBytes > 0 ? downloadedBytes / totalBytes : 0.0;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Downloading $name',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(value: totalBytes > 0 ? fraction : null),
            const SizedBox(height: 8),
            Text(
              totalBytes > 0
                  ? '${(fraction * 100).toStringAsFixed(0)}%'
                  : 'Starting…',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.message);
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );
}

/// The first-run state, with the one action that clears it.
///
/// Before this existed the app dead-ended here: the blocker named the missing
/// files and offered nothing to tap, on a fresh install, forever (#1554).
///
/// The download is offered rather than started. It is roughly 570 MB, which is
/// a real cost on a metered connection, and a user who would rather wait for
/// Wi-Fi has to be able to.
class _ModelDownload extends StatefulWidget {
  const _ModelDownload({required this.service, required this.onInstalled});

  final MindService service;

  /// Called once every model is on disk — the screen re-runs startup.
  final Future<void> Function() onInstalled;

  @override
  State<_ModelDownload> createState() => _ModelDownloadState();
}

class _ModelDownloadState extends State<_ModelDownload> {
  List<RequiredModel>? _required;
  bool _running = false;
  ModelAcquisitionProgress? _progress;
  List<String> _failed = const [];
  String? _error;
  bool _resumeSupported = false;

  @override
  void initState() {
    super.initState();
    _loadSizes();
  }

  Future<void> _loadSizes() async {
    try {
      final required = await widget.service.missingModels();
      if (mounted) setState(() => _required = required);
    } on Object catch (e) {
      // The size is a nicety; the button must still work without it.
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _download() async {
    setState(() {
      _running = true;
      _failed = const [];
      _error = null;
      _progress = null;
      _resumeSupported = false;
    });

    try {
      await for (final event in widget.service.acquireModels()) {
        if (!mounted) return;
        switch (event) {
          case ModelAcquisitionProgress():
            setState(() => _progress = event);
          case ModelAcquisitionDone(
            :final failedFileNames,
            :final resumeSupported,
          ):
            setState(() {
              _failed = failedFileNames;
              _resumeSupported = resumeSupported;
            });
        }
      }
    } on Object catch (e) {
      if (mounted) setState(() => _error = '$e');
    }

    if (!mounted) return;
    setState(() => _running = false);
    if (_failed.isEmpty && _error == null) await widget.onInstalled();
  }

  static String _megabytes(int bytes) =>
      '${(bytes / (1000 * 1000)).round()} MB';

  bool get _canResume =>
      _resumeSupported || (_progress != null && _progress!.fetched > 0);

  @override
  Widget build(BuildContext context) {
    final required = _required;
    final total = required?.fold<int>(0, (sum, m) => sum + m.sizeBytes);
    final failed = _failed.isNotEmpty;
    final needsRecovery = failed || _error != null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Models are not installed yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            const Text(
              'Airo Mind runs entirely on this device, so it needs the speech '
              'and writing models on disk before it can record. They are '
              'downloaded once and never leave this device.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ScribeTrustSignals(
              state: widget.service.scribeTrustState(modelMissing: true),
            ),
            const SizedBox(height: 8),
            const Text(
              'Best on Wi-Fi — this is a large, one-time download.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (_running) ..._progressViews(context) else _action(total),
            if (failed) ...[
              const SizedBox(height: 16),
              Text(
                'Could not download ${_failed.join(', ')}. Check the '
                'connection and ${_canResume ? 'resume' : 'try again'}.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              SelectableText(
                _error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (!_running && needsRecovery) ...[
              const SizedBox(height: 8),
              Text(
                _canResume
                    ? 'Partial download kept where the platform allows it.'
                    : 'No partial download to resume on this device.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _action(int? total) {
    final needsRecovery = _failed.isNotEmpty || _error != null;
    final String label;
    final IconData icon;
    if (!needsRecovery) {
      label = total == null
          ? 'Download models'
          : 'Download models (~${_megabytes(total)})';
      icon = Icons.download;
    } else if (_canResume) {
      label = 'Resume download';
      icon = Icons.download;
    } else {
      label = 'Try again';
      icon = Icons.refresh;
    }
    return FilledButton.icon(
      key: Key(
        needsRecovery
            ? 'mind_model_download_retry'
            : 'mind_model_download_start',
      ),
      onPressed: _download,
      icon: Icon(icon),
      label: Text(label),
    );
  }

  List<Widget> _progressViews(BuildContext context) {
    final progress = _progress;
    final fraction = progress == null || progress.total <= 0
        ? null
        : progress.fetched / progress.total;
    return [
      // Indeterminate until the first byte count arrives: a bar sitting at
      // zero and a bar that has not started look the same, and only one of
      // them means the download is stuck.
      LinearProgressIndicator(value: fraction),
      const SizedBox(height: 12),
      Text(
        progress == null
            ? 'Starting download…'
            : '${progress.fileName} — '
                  '${_megabytes(progress.fetched)} of '
                  '${_megabytes(progress.total)}',
        textAlign: TextAlign.center,
      ),
    ];
  }
}

/// Why the app cannot start, and what to do about it.
///
/// Each case names the actual cause. "Something went wrong" would make the
/// commonest first-run state — models not downloaded — indistinguishable from a
/// broken build.
class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.status});

  final MindStatus status;

  @override
  Widget build(BuildContext context) {
    final (title, body) = switch (status.unavailable!) {
      MindUnavailable.bridgeMissing => (
        'Airo Mind is not available on this platform',
        'The on-device engine could not be loaded. Airo Mind needs the '
            'native runtime, which the web build does not include.',
      ),
      MindUnavailable.modelsMissing => (
        'Models are not installed yet',
        'Airo Mind runs entirely on this device, so it needs the speech and '
            'writing models on disk before it can record.',
      ),
      MindUnavailable.loadFailed => (
        'The models could not be loaded',
        'They are present but did not open. The device may be short of '
            'memory.',
      ),
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(body, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            SelectableText(
              status.detail,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
