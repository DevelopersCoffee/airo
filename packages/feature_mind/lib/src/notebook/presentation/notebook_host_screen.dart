import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../application/audio_import_progress.dart';
import '../application/audio_import_service.dart';
import '../application/notebook_locale_preference.dart';
import '../application/notebook_share_port.dart';
import '../application/notebook_store.dart';
import '../application/super_summary_recap_port.dart';
import '../../capture/application/meeting_capture_providers.dart';
import '../../capture/domain/meeting_processing_job.dart';
import '../../notes/notes_capability.dart';
import '../../notes/presentation/notes_screen.dart';
import '../domain/notebook_l10n.dart';
import 'audio_import_status_banner.dart';

/// Loads the notes log and wires live record / file / podcast import.
class NotebookHostScreen extends ConsumerStatefulWidget {
  const NotebookHostScreen({
    super.key,
    this.onRecordLive,
    this.importer,
    this.sharePort,
    this.recapPort,
  });

  final Future<void> Function()? onRecordLive;
  final AudioImportService? importer;
  final NotebookSharePort? sharePort;
  final SuperSummaryRecapPort? recapPort;

  @override
  ConsumerState<NotebookHostScreen> createState() => _NotebookHostScreenState();
}

class _NotebookHostScreenState extends ConsumerState<NotebookHostScreen> {
  NotesCapability? _capability;
  Object? _error;
  late final AudioImportService _importer =
      widget.importer ?? AudioImportService();
  late final NotebookSharePort _sharePort =
      widget.sharePort ?? const PlatformNotebookSharePort();

  AudioImportProgress? _importProgress;
  String? _trackingJobId;
  StreamSubscription<List<MeetingProcessingJob>>? _queueSub;

  @override
  void initState() {
    super.initState();
    unawaited(_open());
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_listenQueue()));
  }

  @override
  void dispose() {
    unawaited(_queueSub?.cancel());
    super.dispose();
  }

  Future<void> _listenQueue() async {
    if (!mounted) return;
    try {
      final queue = await ref.read(meetingProcessingQueueProvider.future);
      await _queueSub?.cancel();
      _queueSub = queue.jobs.listen(_onQueueJobs);
    } on Object {
      // Provider override missing in tests without ProviderScope.
    }
  }

  void _onQueueJobs(List<MeetingProcessingJob> jobs) {
    final trackingId = _trackingJobId;
    if (trackingId == null) return;
    final job = jobs.cast<MeetingProcessingJob?>().firstWhere(
      (j) => j?.id == trackingId,
      orElse: () => null,
    );
    if (!mounted) return;
    if (job == null) {
      setState(() {
        _importProgress = _importProgress?.copyWith(
          stage: AudioImportStage.completed,
          detail: 'Your note is ready in this list.',
        );
        _trackingJobId = null;
      });
      return;
    }
    if (job.status == MeetingProcessingStatus.failed) {
      setState(() {
        _importProgress = AudioImportProgress.fromJob(job);
        _trackingJobId = null;
      });
      return;
    }
    setState(() => _importProgress = AudioImportProgress.fromJob(job));
  }

  void _reportProgress(AudioImportProgress progress) {
    if (!mounted) return;
    setState(() => _importProgress = progress);
  }

  Future<void> _open() async {
    try {
      final capability = await openNotebookCapability();
      if (!mounted) return;
      setState(() => _capability = capability);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  Future<String> _stagingPath(String sourcePath) async {
    final dir = await getApplicationSupportDirectory();
    final recordingsDir = Directory(p.join(dir.path, 'mind_recordings'));
    await recordingsDir.create(recursive: true);
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final ext = p.extension(sourcePath);
    final safeExt = ext.isEmpty ? '' : ext;
    return p.join(recordingsDir.path, 'import-$stamp$safeExt');
  }

  Future<void> _enqueue({
    required String audioPath,
    required String title,
    required MeetingProcessingSource source,
    required String jobId,
  }) async {
    _reportProgress(
      AudioImportProgress(
        stage: AudioImportStage.enqueueing,
        title: title,
      ),
    );
    final queue = await ref.read(meetingProcessingQueueProvider.future);
    final enqueuedAtMs = DateTime.now().millisecondsSinceEpoch;
    await queue.enqueue(
      _importer.jobFor(
        id: jobId,
        audioPath: audioPath,
        title: title,
        source: source,
        enqueuedAtMs: enqueuedAtMs,
      ),
    );
    _trackingJobId = jobId;
    _reportProgress(
      AudioImportProgress(
        stage: AudioImportStage.queued,
        title: title,
        detail: 'Waiting for on-device transcription…',
      ),
    );
  }

  Future<void> _importAudio() async {
    try {
      final picked = await _importer.pickLocalAudioFile();
      if (picked == null) return;
      final sourceName = picked.name.isNotEmpty
          ? picked.name
          : (picked.path ?? 'import.m4a');
      final title = _importer.titleFromPath(sourceName);
      final jobId = 'import-${DateTime.now().millisecondsSinceEpoch}';
      _reportProgress(
        AudioImportProgress(stage: AudioImportStage.staging, title: title),
      );
      final dest = await _stagingPath(sourceName);
      await _importer.stagePickedFile(
        picked,
        dest,
        onProgress: _reportProgress,
      );
      await _enqueue(
        audioPath: dest,
        title: title,
        source: MeetingProcessingSource.upload,
        jobId: jobId,
      );
    } on Object catch (error) {
      if (!mounted) return;
      setState(
        () => _importProgress = AudioImportProgress(
          stage: AudioImportStage.failed,
          error: '$error',
        ),
      );
    }
  }

  Future<void> _importPodcast() async {
    final l10n = NotebookL10n.of(ref.read(notebookUiLocaleProvider));
    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.importPodcast),
        content: TextField(
          key: const Key('notes_screen_podcast_url_field'),
          controller: controller,
          decoration: InputDecoration(labelText: l10n.podcastUrl),
          keyboardType: TextInputType.url,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const Key('notes_screen_podcast_import_confirm'),
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(l10n.importPodcast),
          ),
        ],
      ),
    );
    if (url == null || url.isEmpty) return;

    final jobId = 'import-${DateTime.now().millisecondsSinceEpoch}';
    _reportProgress(
      AudioImportProgress(
        stage: AudioImportStage.resolving,
        title: _importer.titleFromUrl(url),
      ),
    );

    try {
      if (_importer.isYoutubeUrl(url)) {
        final dest = await _stagingPath('youtube.m4a');
        final result = await _importer.downloadYoutube(
          url: url,
          destPath: dest,
          onProgress: _reportProgress,
        );
        await _enqueue(
          audioPath: result.path,
          title: result.title,
          source: MeetingProcessingSource.podcast,
          jobId: jobId,
        );
        return;
      }
      final dest = await _stagingPath('podcast.m4a');
      await _importer.downloadRemote(
        url: url,
        destPath: dest,
        onProgress: _reportProgress,
      );
      await _enqueue(
        audioPath: dest,
        title: _importer.titleFromUrl(url),
        source: MeetingProcessingSource.podcast,
        jobId: jobId,
      );
    } on Object catch (error) {
      if (!mounted) return;
      setState(
        () => _importProgress = AudioImportProgress(
          stage: AudioImportStage.failed,
          title: _importer.titleFromUrl(url),
          error: '$error',
        ),
      );
    }
  }

  void _dismissImportBanner() {
    setState(() => _importProgress = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notes')),
        body: Center(child: Text('Could not open notes log: $_error')),
      );
    }
    if (_capability == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final locale = ref.watch(notebookUiLocaleProvider);
    return Stack(
      children: [
        NotesScreen(
          capability: _capability!,
          sharePort: _sharePort,
          recapPort: widget.recapPort,
          localeCode: locale,
          onBack: () => Navigator.of(context).maybePop(),
          onRecordLive: widget.onRecordLive,
          onImportAudio: _importAudio,
          onImportPodcast: _importPodcast,
        ),
        if (_importProgress != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              child: AudioImportStatusBanner(
                progress: _importProgress!,
                onDismiss: _importProgress!.isTerminal
                    ? _dismissImportBanner
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}
