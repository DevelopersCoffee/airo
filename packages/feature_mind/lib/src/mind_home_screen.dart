import 'package:flutter/material.dart';

import 'api/mind.dart' as rust;
import 'meeting_screen.dart';
import 'mind_service.dart';

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

  MindStatus? _status;
  List<rust.MeetingRecord> _meetings = const [];
  List<rust.SearchHit>? _hits;
  bool _recording = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final status = await widget.service.initialize();
    if (!mounted) return;
    setState(() => _status = status);
    if (status.isReady) await _refresh();
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
      final progress = widget.service.process(wavPath: path, title: title);
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
      appBar: AppBar(title: const Text('Airo Mind')),
      body: switch (status) {
        null => const Center(child: CircularProgressIndicator()),
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
            m.minutes.trim().isEmpty ? m.transcript : m.minutes.trim(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => _open(m.id),
        );
      },
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
