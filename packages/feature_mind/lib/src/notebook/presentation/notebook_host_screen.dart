import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../application/audio_import_service.dart';
import '../application/notebook_locale_preference.dart';
import '../application/notebook_share_port.dart';
import '../application/notebook_store.dart';
import '../../capture/application/meeting_capture_providers.dart';
import '../../capture/domain/meeting_processing_job.dart';
import '../../notes/notes_capability.dart';
import '../../notes/presentation/notes_screen.dart';
import '../domain/notebook_l10n.dart';

/// Loads the notes log and wires live record / file / podcast import.
class NotebookHostScreen extends ConsumerStatefulWidget {
  const NotebookHostScreen({
    super.key,
    this.onRecordLive,
    this.importer,
    this.sharePort,
  });

  final Future<void> Function()? onRecordLive;
  final AudioImportService? importer;
  final NotebookSharePort? sharePort;

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

  @override
  void initState() {
    super.initState();
    unawaited(_open());
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
    final safeExt = ext.isEmpty ? '.m4a' : ext;
    return p.join(recordingsDir.path, 'import-$stamp$safeExt');
  }

  Future<void> _enqueue({
    required String audioPath,
    required String title,
    required MeetingProcessingSource source,
  }) async {
    final queue = await ref.read(meetingProcessingQueueProvider.future);
    await queue.enqueue(
      _importer.jobFor(
        audioPath: audioPath,
        title: title,
        source: source,
        enqueuedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Queued "$title" for transcription')),
    );
  }

  Future<void> _importAudio() async {
    try {
      final picked = await _importer.pickLocalAudio();
      if (picked == null) return;
      final dest = await _stagingPath(picked);
      await File(picked).copy(dest);
      await _enqueue(
        audioPath: dest,
        title: _importer.titleFromPath(picked),
        source: MeetingProcessingSource.upload,
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Import failed: $error')));
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
    try {
      final guessedExt = p.extension(Uri.tryParse(url)?.path ?? '');
      final dest = await _stagingPath(
        guessedExt.isEmpty ? 'podcast.mp3' : 'podcast$guessedExt',
      );
      await _importer.downloadRemote(url: url, destPath: dest);
      await _enqueue(
        audioPath: dest,
        title: _importer.titleFromUrl(url),
        source: MeetingProcessingSource.podcast,
      );
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Podcast import failed: $error')));
    }
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
    return NotesScreen(
      capability: _capability!,
      sharePort: _sharePort,
      localeCode: locale,
      onBack: () => Navigator.of(context).maybePop(),
      onRecordLive: widget.onRecordLive,
      onImportAudio: _importAudio,
      onImportPodcast: _importPodcast,
    );
  }
}
