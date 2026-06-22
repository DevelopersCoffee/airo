import 'package:flutter/material.dart';

import '../../application/services/meeting_session_controller.dart';
import '../../domain/entities/meeting.dart';
import '../../infrastructure/storage/in_memory_meeting_repository.dart';
import '../../infrastructure/whisper/native_meeting_services.dart';

class MeetingHomeScreen extends StatefulWidget {
  const MeetingHomeScreen({super.key});

  @override
  State<MeetingHomeScreen> createState() => _MeetingHomeScreenState();
}

class _MeetingHomeScreenState extends State<MeetingHomeScreen> {
  late final InMemoryMeetingRepository _repository;
  late final MeetingSessionController _controller;
  String _summary =
      'Start Live Notes to capture team conversations, decisions, actions, risks, and next steps offline.';

  @override
  void initState() {
    super.initState();
    _repository = InMemoryMeetingRepository();
    _controller = MeetingSessionController(
      repository: _repository,
      transcriptionService: FallbackMeetingTranscriptionService(),
    )..addListener(_refresh);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.state;
    final isRecording = state.recordingState == RecordingState.recording;
    final isPaused = state.recordingState == RecordingState.paused;
    final canPauseOrResume = isRecording || isPaused;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Live Notes',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Explicit, local note capture for team conversations. Airo listens only after you start, then turns notes into follow-ups you can act on.',
            ),
            const SizedBox(height: 24),
            _RecordingCard(state: state),
            const SizedBox(height: 16),
            _MeetingControls(
              canStart: !isRecording && !isPaused,
              canPauseOrResume: canPauseOrResume,
              canStop: canPauseOrResume,
              isPaused: isPaused,
              onStart: _startMeeting,
              onPauseOrResume: isPaused ? _resumeMeeting : _pauseMeeting,
              onStop: _stopMeeting,
            ),
            const SizedBox(height: 24),
            Text(
              'Realtime Transcript',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            _TranscriptPanel(text: state.visibleTranscript),
            if (state.errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                state.errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 24),
            Text(
              'Generated Intelligence',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_summary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startMeeting() async {
    await _controller.startMeeting(
      title: 'Airo live notes ${DateTime.now().toLocal()}',
    );
    _summary =
        'Live Notes is listening locally. Audio and transcript stay on this device.';
    _refresh();
  }

  Future<void> _pauseMeeting() async {
    await _controller.pauseMeeting();
    setState(() {});
  }

  Future<void> _resumeMeeting() async {
    await _controller.resumeMeeting();
    setState(() {});
  }

  Future<void> _stopMeeting() async {
    final intelligence = await _controller.stopMeeting();
    _summary = [
      intelligence.summary.executiveSummary,
      if (intelligence.summary.keyDecisions.isNotEmpty)
        'Decisions: ${intelligence.summary.keyDecisions.join('; ')}',
      if (intelligence.actionItems.isNotEmpty)
        'Actions: ${intelligence.actionItems.map((item) => item.description).join('; ')}',
      if (intelligence.summary.risks.isNotEmpty)
        'Risks: ${intelligence.summary.risks.join('; ')}',
      'Privacy: offline-only, no upload.',
    ].join('\n');
    _refresh();
  }
}

class _MeetingControls extends StatelessWidget {
  const _MeetingControls({
    required this.canStart,
    required this.canPauseOrResume,
    required this.canStop,
    required this.isPaused,
    required this.onStart,
    required this.onPauseOrResume,
    required this.onStop,
  });

  final bool canStart;
  final bool canPauseOrResume;
  final bool canStop;
  final bool isPaused;
  final VoidCallback onStart;
  final VoidCallback onPauseOrResume;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: canStart ? onStart : null,
              icon: const Icon(Icons.mic),
              label: const Text('Start Live Notes'),
            ),
            OutlinedButton.icon(
              onPressed: canPauseOrResume ? onPauseOrResume : null,
              icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
              label: Text(isPaused ? 'Resume' : 'Pause'),
            ),
            FilledButton.tonalIcon(
              onPressed: canStop ? onStop : null,
              icon: const Icon(Icons.stop),
              label: const Text('Stop'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordingCard extends StatelessWidget {
  const _RecordingCard({required this.state});

  final MeetingSessionState state;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _iconFor(state.recordingState),
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'State: ${state.recordingState.name}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: state.recordingState == RecordingState.recording
                    ? null
                    : 0,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Transcript events stream locally after explicit start. Native Whisper channels are used when available; preview builds fall back to an offline local stream.',
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(RecordingState state) {
    return switch (state) {
      RecordingState.recording => Icons.fiber_manual_record,
      RecordingState.paused => Icons.pause_circle,
      RecordingState.stopped => Icons.check_circle,
      RecordingState.cancelled => Icons.cancel,
      RecordingState.failed => Icons.error,
      RecordingState.idle => Icons.mic_none,
    };
  }
}

class _TranscriptPanel extends StatelessWidget {
  const _TranscriptPanel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          text.isEmpty
              ? 'Live transcript will appear here as local transcription chunks arrive.'
              : text,
        ),
      ),
    );
  }
}
