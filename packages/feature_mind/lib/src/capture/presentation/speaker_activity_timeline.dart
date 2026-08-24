import 'package:flutter/material.dart';

import '../domain/live_speaker_label.dart';
import '../domain/speaker_activity_span.dart';

/// Per-speaker activity lanes for provisional live diarization (`P1`).
///
/// Does not color amplitude bars — separate lanes only. Assignments may be
/// reconciled after recording by final diarization.
class SpeakerActivityTimeline extends StatelessWidget {
  const SpeakerActivityTimeline({
    required this.spans,
    required this.timelineEndMs,
    this.windowMs = 30000,
    this.activeSpeakerIndex,
    super.key,
  });

  final List<SpeakerActivitySpan> spans;
  final int timelineEndMs;
  final int windowMs;
  final int? activeSpeakerIndex;

  @override
  Widget build(BuildContext context) {
    if (spans.isEmpty && activeSpeakerIndex == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final windowStart = timelineEndMs > windowMs ? timelineEndMs - windowMs : 0;
    final speakerIndices = _laneIndices(spans, activeSpeakerIndex);

    return Column(
      key: const Key('meeting_capture_speaker_activity'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Speaker activity',
          style: theme.textTheme.labelSmall?.copyWith(
            letterSpacing: 1.1,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        for (final index in speakerIndices)
          _SpeakerLane(
            speakerIndex: index,
            spans: spans,
            windowStartMs: windowStart,
            windowEndMs: timelineEndMs,
            isActive: activeSpeakerIndex == index,
          ),
      ],
    );
  }

  List<int> _laneIndices(
    List<SpeakerActivitySpan> spans,
    int? activeSpeakerIndex,
  ) {
    final indices = <int>{};
    for (final span in spans) {
      indices.add(span.speakerIndex);
    }
    if (activeSpeakerIndex != null) {
      indices.add(activeSpeakerIndex);
    }
    final sorted = indices.toList()..sort();
    return sorted;
  }
}

class _SpeakerLane extends StatelessWidget {
  const _SpeakerLane({
    required this.speakerIndex,
    required this.spans,
    required this.windowStartMs,
    required this.windowEndMs,
    required this.isActive,
  });

  final int speakerIndex;
  final List<SpeakerActivitySpan> spans;
  final int windowStartMs;
  final int windowEndMs;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final laneSpans = spans
        .where((span) => span.speakerIndex == speakerIndex)
        .where((span) => span.endMs > windowStartMs)
        .toList();
    final windowWidth = (windowEndMs - windowStartMs).clamp(1, 1 << 30);
    final label = formatLiveSpeakerLabel('sp$speakerIndex');
    final laneColor = theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                return SizedBox(
                  height: 14,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (final span in laneSpans)
                        Positioned(
                          left: _fraction(span.startMs, windowStartMs, windowWidth) * width,
                          width: _spanWidth(span, windowStartMs, windowWidth, width),
                          top: 3,
                          height: 8,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: laneColor.withValues(
                                alpha: isActive ? 0.85 : 0.55,
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            key: Key('speaker_lane_label_$speakerIndex'),
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  double _fraction(int ms, int windowStartMs, int windowWidth) {
    final clamped = ms.clamp(windowStartMs, windowStartMs + windowWidth);
    return (clamped - windowStartMs) / windowWidth;
  }

  double _spanWidth(
    SpeakerActivitySpan span,
    int windowStartMs,
    int windowWidth,
    double laneWidth,
  ) {
    final start = span.startMs.clamp(windowStartMs, windowStartMs + windowWidth);
    final end = span.endMs.clamp(windowStartMs, windowStartMs + windowWidth);
    final fraction = (end - start) / windowWidth;
    return (fraction * laneWidth).clamp(4.0, laneWidth);
  }
}
