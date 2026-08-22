import 'package:flutter/material.dart';

import '../domain/live_transcript_line.dart';
import '../domain/live_speaker_label.dart';

/// Primary live transcript surface — scroll, follow-live, jump-to-live (`P0`).
class LiveTranscriptView extends StatefulWidget {
  const LiveTranscriptView({
    required this.lines,
    required this.followLive,
    required this.onFollowLiveChanged,
    super.key,
  });

  final List<LiveTranscriptLine> lines;
  final bool followLive;
  final ValueChanged<bool> onFollowLiveChanged;

  @override
  State<LiveTranscriptView> createState() => _LiveTranscriptViewState();
}

class _LiveTranscriptViewState extends State<LiveTranscriptView> {
  final _scrollController = ScrollController();
  bool _showJumpToLive = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant LiveTranscriptView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.followLive && widget.lines.length != oldWidget.lines.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final atBottom = _scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 48;
    if (!atBottom && widget.followLive) {
      widget.onFollowLiveChanged(false);
    }
    setState(() => _showJumpToLive = !atBottom);
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _jumpToLive() {
    widget.onFollowLiveChanged(true);
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                'LIVE TRANSCRIPT',
                style: theme.textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: widget.lines.isEmpty
                  ? Center(
                      key: const Key('meeting_capture_live_listening'),
                      child: Text(
                        'Listening…',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    )
                  : ListView.builder(
                      key: const Key('meeting_capture_live_transcript'),
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: widget.lines.length,
                      itemBuilder: (context, index) {
                        final line = widget.lines[index];
                        return _TranscriptLineTile(line: line);
                      },
                    ),
            ),
          ],
        ),
        if (_showJumpToLive && !widget.followLive)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Center(
              child: FilledButton.tonalIcon(
                key: const Key('meeting_capture_jump_to_live'),
                onPressed: _jumpToLive,
                icon: const Icon(Icons.arrow_downward),
                label: const Text('Jump to live'),
              ),
            ),
          ),
      ],
    );
  }
}

class _TranscriptLineTile extends StatelessWidget {
  const _TranscriptLineTile({required this.line});

  final LiveTranscriptLine line;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final speakerStyle = theme.textTheme.titleSmall?.copyWith(
      fontWeight: FontWeight.w700,
    );
    final bodyStyle = line.isPartial
        ? theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
          )
        : theme.textTheme.bodyLarge;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.circle,
                size: 10,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text(
                line.speakerLabel,
                key: Key('live_speaker_${line.segmentId}'),
                style: speakerStyle,
              ),
              const Spacer(),
              Text(
                formatLiveSegmentClock(line.startMs),
                key: Key('live_time_${line.segmentId}'),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: line.text, style: bodyStyle),
                  if (line.isPartial)
                    TextSpan(
                      text: ' ▌',
                      style: bodyStyle?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                ],
              ),
              key: Key('live_text_${line.segmentId}'),
            ),
          ),
        ],
      ),
    );
  }
}
