import 'dart:async';

import 'package:flutter/material.dart';
import 'package:platform_player/platform_player.dart';

import 'cast_device_picker_sheet.dart';

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
    required this.castController,
  });

  final PhoneLocalMediaItem item;
  final PhoneMediaCastHandoff handoff;
  final AiroCastController castController;

  @override
  State<PhoneMediaPlayOnTvSheet> createState() =>
      _PhoneMediaPlayOnTvSheetState();
}

enum _HandoffPhase { idle, connecting, starting, playing, unsupported, failed }

class _PhoneMediaPlayOnTvSheetState extends State<PhoneMediaPlayOnTvSheet> {
  _HandoffPhase _phase = _HandoffPhase.idle;
  late AiroCastDiscoveryState _discovery;
  late AiroCastSessionSnapshot _session;
  AiroCastDevice? _targetDevice;
  StreamSubscription<AiroCastDiscoveryState>? _discoverySubscription;
  StreamSubscription<AiroCastSessionSnapshot>? _sessionSubscription;

  @override
  void initState() {
    super.initState();
    _discovery = widget.castController.currentDiscoveryState;
    _session = widget.castController.currentSessionState;
    _discoverySubscription = widget.castController.discoveryStateStream.listen((
      state,
    ) {
      if (mounted) setState(() => _discovery = state);
    });
    _sessionSubscription = widget.castController.sessionStateStream.listen((
      state,
    ) {
      if (mounted) setState(() => _session = state);
    });
    if (!_session.isConnected) {
      unawaited(_startDiscovery());
    }
  }

  @override
  void dispose() {
    unawaited(_discoverySubscription?.cancel());
    unawaited(_sessionSubscription?.cancel());
    unawaited(widget.handoff.dispose());
    super.dispose();
  }

  Future<void> _startDiscovery() async {
    if (mounted) {
      setState(() {
        _phase = _HandoffPhase.idle;
        _discovery = AiroCastDiscoveryState.discovering(
          devices: _discovery.devices,
        );
      });
    }
    await widget.castController.initialize();
    await widget.castController.startDiscovery();
    if (!mounted) return;
    setState(() => _discovery = widget.castController.currentDiscoveryState);
  }

  Future<void> _connectAndStart(AiroCastDevice device) async {
    setState(() {
      _targetDevice = device;
      _phase = _HandoffPhase.connecting;
    });
    await widget.castController.connect(device);
    if (!mounted) return;
    final session = widget.castController.currentSessionState;
    setState(() => _session = session);
    if (!session.isConnected) {
      setState(() => _phase = _HandoffPhase.failed);
      return;
    }
    await widget.castController.stopDiscovery();
    await _startHandoff();
  }

  Future<void> _startHandoff() async {
    if (!widget.castController.currentSessionState.isConnected) {
      await _startDiscovery();
      return;
    }
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
    final deviceName = _session.device?.name ?? _targetDevice?.name;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: switch (_phase) {
          _HandoffPhase.idle when !_session.isConnected => [
            Text(widget.item.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text(
              'Choose a Chromecast-enabled TV on this Wi-Fi network. The '
              'video streams from your phone and is not stored on the TV.',
            ),
            const SizedBox(height: 12),
            CastDiscoveryBody(
              discovery: _discovery,
              onRetry: _startDiscovery,
              onDeviceSelected: _connectAndStart,
            ),
          ],
          _HandoffPhase.idle || _HandoffPhase.starting => [
            Text(widget.item.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Send this video to $deviceName. It streams from your phone - '
              'nothing is stored on the TV.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _phase == _HandoffPhase.starting
                  ? null
                  : _startHandoff,
              icon: const Icon(Icons.cast),
              label: Text('Play on $deviceName'),
            ),
          ],
          _HandoffPhase.connecting => [
            Text(
              'Connecting to $deviceName',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          _HandoffPhase.playing => [
            Text('Playing on $deviceName', style: theme.textTheme.titleMedium),
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
              _session.error?.message ??
                  'The stream could not start. Check that both devices are on '
                      'the same Wi-Fi network.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _session.isConnected
                  ? () => setState(() => _phase = _HandoffPhase.idle)
                  : _startDiscovery,
              child: Text(_session.isConnected ? 'Try again' : 'Find a TV'),
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
