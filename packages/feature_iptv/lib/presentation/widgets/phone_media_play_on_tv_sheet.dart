import 'package:flutter/material.dart';
import 'package:platform_player/platform_player.dart';

/// "Play on TV" surface for a phone-local media file (CV-033).
///
/// Streams the file to the connected receiver through [PhoneMediaCastHandoff];
/// the phone stays the remote. Unsupported container/codec combinations get an
/// explicit failure state instead of a silent broken handoff.
class PhoneMediaPlayOnTvSheet extends StatefulWidget {
  const PhoneMediaPlayOnTvSheet({
    super.key,
    required this.item,
    required this.handoff,
  });

  final PhoneLocalMediaItem item;
  final PhoneMediaCastHandoff handoff;

  @override
  State<PhoneMediaPlayOnTvSheet> createState() =>
      _PhoneMediaPlayOnTvSheetState();
}

enum _HandoffPhase { idle, starting, playing, unsupported, failed }

class _PhoneMediaPlayOnTvSheetState extends State<PhoneMediaPlayOnTvSheet> {
  _HandoffPhase _phase = _HandoffPhase.idle;

  @override
  void dispose() {
    widget.handoff.dispose();
    super.dispose();
  }

  Future<void> _startHandoff() async {
    setState(() => _phase = _HandoffPhase.starting);
    final result = await widget.handoff.start(widget.item);
    if (!mounted) return;
    setState(() {
      _phase = switch (result) {
        PhoneMediaHandoffStarted() => _HandoffPhase.playing,
        PhoneMediaHandoffUnsupported() => _HandoffPhase.unsupported,
        PhoneMediaHandoffFailed() => _HandoffPhase.failed,
      };
    });
  }

  Future<void> _stopHandoff() async {
    await widget.handoff.stopHandoff();
    if (!mounted) return;
    setState(() => _phase = _HandoffPhase.idle);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final deviceName =
        widget.handoff.connectedDeviceName ?? 'a Chromecast-enabled TV';

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: switch (_phase) {
          _HandoffPhase.idle || _HandoffPhase.starting => [
            Text(widget.item.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Send this video to $deviceName. It streams from your phone — '
              'nothing is stored on the TV.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _phase == _HandoffPhase.starting
                  ? null
                  : _startHandoff,
              icon: const Icon(Icons.cast),
              label: const Text('Play on TV'),
            ),
          ],
          _HandoffPhase.playing => [
            Text(
              'Playing on $deviceName',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.item.title} is streaming from your phone. '
              'Use this device as the remote.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _stopHandoff,
              icon: const Icon(Icons.stop),
              label: const Text('Stop casting'),
            ),
          ],
          _HandoffPhase.failed => [
            Text(
              "Couldn't play on your TV",
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'The stream could not start. Check that both devices are on '
              'the same Wi-Fi network.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() => _phase = _HandoffPhase.idle),
              child: const Text('Try again'),
            ),
          ],
          _HandoffPhase.unsupported => [
            Text(
              "This format isn't supported by your TV",
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Your TV cannot decode this file '
              '(.${widget.item.container}). Converting formats is not '
              'supported yet.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => setState(() => _phase = _HandoffPhase.idle),
              child: const Text('Back'),
            ),
          ],
        },
      ),
    );
  }
}
