import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../application/providers/tv_playlist_pairing_provider.dart';
import '../../application/services/tv_playlist_pairing_server.dart';

/// Empty-state "phone QR" onboarding (issues/04-recovery-states.md): shows
/// a QR code for a short-lived LAN-only pairing session, lets the user
/// cancel or regenerate on expiry, and returns the phone-submitted URL (or
/// `null` if cancelled/expired) to the caller.
class TvPlaylistQrDialog extends ConsumerStatefulWidget {
  const TvPlaylistQrDialog({super.key});

  @override
  ConsumerState<TvPlaylistQrDialog> createState() => _TvPlaylistQrDialogState();
}

enum _PairingStatus { waiting, expired }

class _TvPlaylistQrDialogState extends ConsumerState<TvPlaylistQrDialog> {
  TvPlaylistPairingServer? _server;
  Uri? _pairingUrl;
  _PairingStatus _status = _PairingStatus.waiting;
  Object? _startError;

  @override
  void initState() {
    super.initState();
    unawaited(_startSession());
  }

  @override
  void dispose() {
    unawaited(_server?.stop());
    super.dispose();
  }

  Future<void> _startSession() async {
    final previous = _server;
    if (previous != null) unawaited(previous.stop());

    final server = ref.read(tvPlaylistPairingServerFactoryProvider)();
    setState(() {
      _server = server;
      _pairingUrl = null;
      _status = _PairingStatus.waiting;
      _startError = null;
    });

    try {
      final url = await server.start();
      if (!mounted) return;
      setState(() => _pairingUrl = url);
      final submittedUrl = await server.result;
      if (!mounted) return;
      if (submittedUrl != null) {
        Navigator.of(context).pop(submittedUrl);
        return;
      }
      setState(() => _status = _PairingStatus.expired);
    } catch (error) {
      if (!mounted) return;
      setState(() => _startError = error);
    }
  }

  void _cancel() {
    unawaited(_server?.stop());
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Scan with your phone',
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Connect to the same Wi-Fi, scan the code, and type your '
                'playlist link on your phone.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              _buildBody(theme),
              const SizedBox(height: 20),
              TvFocusable(
                key: const ValueKey('tv-playlist-qr-cancel'),
                semanticLabel: 'Cancel',
                autofocus: true,
                onSelect: _cancel,
                borderRadius: 8,
                child: OutlinedButton(
                  onPressed: _cancel,
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_startError != null) {
      return Text(
        "Couldn't start pairing — check your TV's Wi-Fi connection.",
        key: const ValueKey('tv-playlist-qr-error'),
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.error,
        ),
        textAlign: TextAlign.center,
      );
    }
    if (_status == _PairingStatus.expired) {
      return Column(
        key: const ValueKey('tv-playlist-qr-expired'),
        children: [
          Text('QR code expired', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          TvFocusable(
            key: const ValueKey('tv-playlist-qr-regenerate'),
            semanticLabel: 'Generate new code',
            onSelect: () => unawaited(_startSession()),
            borderRadius: 8,
            child: FilledButton(
              onPressed: () => unawaited(_startSession()),
              child: const Text('Generate new code'),
            ),
          ),
        ],
      );
    }
    final url = _pairingUrl;
    if (url == null) {
      return const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Column(
      key: const ValueKey('tv-playlist-qr-waiting'),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: QrImageView(
            data: url.toString(),
            size: 200,
            backgroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Text('Waiting for your phone…', style: theme.textTheme.bodySmall),
      ],
    );
  }
}
