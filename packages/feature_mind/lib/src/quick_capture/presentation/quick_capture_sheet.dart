import 'package:flutter/material.dart';

import '../../runtime/models/context_models.dart';
import '../../widgets/grouped_number.dart';
import '../../widgets/mind_context_chip.dart';
import '../../widgets/mind_palette.dart';
import '../../widgets/mind_presence_pip.dart';
import '../application/quick_capture_controller.dart';
import '../application/quick_capture_state.dart';

/// Surface 07, phone: hold to talk, transcription lands before release, the
/// suggested context is overridable, capture never blocks on classification.
///
/// A bottom sheet rather than a screen -- the design's "does not open the
/// full app" applies just as much to the phone as it does to the menu bar
/// extra and the tray flyout; this is the one surface of the three that
/// ships in this pass.
class QuickCaptureSheet extends StatefulWidget {
  const QuickCaptureSheet({
    super.key,
    required this.controller,
    required this.contextCandidates,
  });

  final QuickCaptureController controller;

  /// Contexts a person can tap to override the guess. Fetched by the caller
  /// (typically `ContextPort.all()`) rather than by this widget, so a golden
  /// test can hand it a fixed list without waiting on a future.
  final List<MindContext> contextCandidates;

  @override
  State<QuickCaptureSheet> createState() => _QuickCaptureSheetState();
}

class _QuickCaptureSheetState extends State<QuickCaptureSheet> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  MindContext? _contextById(String? id) {
    if (id == null) return null;
    for (final context in widget.contextCandidates) {
      if (context.id == id) return context;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xFF041C1C)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        // One gesture detector for the whole sheet, spanning idle and
        // capturing, so the hold-then-release gesture resolves in a single
        // gesture arena. Two separate detectors swapped mid-rebuild (one in
        // the idle child, one in the capturing child) would lose the
        // in-progress pointer the moment the tree swaps them.
        child: GestureDetector(
          key: const Key('quickCapture.holdTarget'),
          // Opaque rather than the default deferToChild: the Column beneath
          // reports the sheet's full box under the tight constraints a host
          // Scaffold gives it, but its content only paints the top of that
          // box. deferToChild would only register a hold where a child
          // happens to paint; a person holding anywhere in the sheet must
          // start the capture.
          behavior: HitTestBehavior.opaque,
          onLongPressStart: (_) => widget.controller.startCapture(),
          onLongPressEnd: (_) => widget.controller.releaseCapture(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Rule R01: a presence pip on every Mind screen.
              const MindPresencePip(isLocal: true),
              const SizedBox(height: 16),
              switch (state.phase) {
                QuickCapturePhase.idle => const _IdlePrompt(),
                QuickCapturePhase.capturing => _Capturing(
                  transcript: state.transcript,
                ),
                QuickCapturePhase.transcribed => _Transcribed(
                  state: state,
                  candidates: widget.contextCandidates,
                  suggested: _contextById(state.effectiveContextId),
                  onOverride: widget.controller.overrideContext,
                  onCommit: () => widget.controller.commit(
                    title: state.transcript.isEmpty
                        ? 'Untitled capture'
                        : state.transcript,
                  ),
                ),
                // No spinner without a number: filing always carries the op
                // number it will land on.
                QuickCapturePhase.filing => _Filing(
                  sequence: state.provisionalSequence,
                ),
                QuickCapturePhase.filed => _Filed(
                  sequence: state.filedSequence,
                  onDone: widget.controller.reset,
                ),
                QuickCapturePhase.error => _CaptureError(
                  missingPort: state.missingPort,
                  message: state.errorMessage,
                  onDismiss: widget.controller.reset,
                ),
              },
            ],
          ),
        ),
      ),
    );
  }
}

class _IdlePrompt extends StatelessWidget {
  const _IdlePrompt();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.mic, color: MindPalette.local, size: 28),
          SizedBox(width: 12),
          Text('Hold to talk', style: TextStyle(color: MindPalette.ink)),
        ],
      ),
    );
  }
}

/// Live while the thumb is down. Carries no gesture handling of its own --
/// the sheet's one [GestureDetector] spans both this and [_IdlePrompt] so the
/// hold-then-release gesture resolves in a single arena.
class _Capturing extends StatelessWidget {
  const _Capturing({required this.transcript});

  final String transcript;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.fiber_manual_record, color: MindPalette.alarm, size: 12),
            SizedBox(width: 8),
            Text('Listening…', style: TextStyle(color: MindPalette.ink)),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          transcript.isEmpty ? '…' : transcript,
          key: const Key('quickCapture.liveTranscript'),
          style: const TextStyle(color: MindPalette.ink, fontSize: 16),
        ),
      ],
    );
  }
}

class _Transcribed extends StatelessWidget {
  const _Transcribed({
    required this.state,
    required this.candidates,
    required this.suggested,
    required this.onOverride,
    required this.onCommit,
  });

  final QuickCaptureState state;
  final List<MindContext> candidates;
  final MindContext? suggested;
  final ValueChanged<String> onOverride;
  final VoidCallback onCommit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          state.transcript,
          key: const Key('quickCapture.finalTranscript'),
          style: const TextStyle(color: MindPalette.ink, fontSize: 16),
        ),
        const SizedBox(height: 12),
        // The guess is a suggestion, not a gate -- filing works whether or
        // not one arrived, and every candidate stays tappable to override it.
        if (state.isClassifying)
          const Text(
            'Suggesting a context…',
            style: TextStyle(color: MindPalette.remote, fontSize: 12),
          )
        else if (candidates.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final candidate in candidates)
                MindContextChip(
                  context: candidate,
                  isSelected: candidate.id == suggested?.id,
                  onTap: () => onOverride(candidate.id),
                ),
            ],
          ),
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('quickCapture.commit'),
          onPressed: onCommit,
          child: const Text('Commit'),
        ),
      ],
    );
  }
}

class _Filing extends StatelessWidget {
  const _Filing({required this.sequence});

  final int? sequence;

  @override
  Widget build(BuildContext context) {
    return Text(
      sequence == null
          ? 'Filing…'
          : 'Filing as op #${groupedNumber(sequence!)}',
      key: const Key('quickCapture.filing'),
      style: const TextStyle(color: MindPalette.ink),
    );
  }
}

class _Filed extends StatelessWidget {
  const _Filed({required this.sequence, required this.onDone});

  final int? sequence;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          sequence == null
              ? 'Filed.'
              : 'Filed as op #${groupedNumber(sequence!)}',
          key: const Key('quickCapture.filed'),
          style: const TextStyle(color: MindPalette.local),
        ),
        const SizedBox(height: 12),
        TextButton(onPressed: onDone, child: const Text('Capture another')),
      ],
    );
  }
}

class _CaptureError extends StatelessWidget {
  const _CaptureError({
    required this.missingPort,
    required this.message,
    required this.onDismiss,
  });

  final String? missingPort;
  final String? message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          missingPort == null
              ? 'Capture failed.'
              : 'The $missingPort is not available.',
          key: const Key('quickCapture.error'),
          style: const TextStyle(color: MindPalette.alarm),
        ),
        if (message != null && message!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            message!,
            style: TextStyle(color: MindPalette.ink.withValues(alpha: 0.7)),
          ),
        ],
        const SizedBox(height: 12),
        TextButton(onPressed: onDismiss, child: const Text('Dismiss')),
      ],
    );
  }
}
