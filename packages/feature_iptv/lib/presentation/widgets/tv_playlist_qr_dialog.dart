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
class TvPlaylistQrDialog extends StatelessWidget {
  const TvPlaylistQrDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: TvPlaylistQrPanel(
          onUrlSubmitted: (url) => Navigator.of(context).pop(url),
          onCancel: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}

/// LAN-only QR pairing panel. Used by [TvPlaylistQrDialog] and the 10-foot
/// empty Home. Never logs the submitted playlist URL.
class TvPlaylistQrPanel extends ConsumerStatefulWidget {
  const TvPlaylistQrPanel({
    super.key,
    this.onUrlSubmitted,
    this.onCancel,
    this.showHeading = true,
    this.showCancel = true,
    this.restartAfterResult = false,
  });

  final FutureOr<void> Function(String)? onUrlSubmitted;
  final VoidCallback? onCancel;
  final bool showHeading;
  final bool showCancel;

  /// Embedded Home keeps this panel mounted after a phone submit, so a
  /// new pairing session must replace the consumed QR. The dialog pops
  /// instead and leaves this false.
  final bool restartAfterResult;

  @override
  ConsumerState<TvPlaylistQrPanel> createState() => _TvPlaylistQrPanelState();
}

enum _PairingStatus { waiting, expired }

class _TvPlaylistQrPanelState extends ConsumerState<TvPlaylistQrPanel> {
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
        await widget.onUrlSubmitted?.call(submittedUrl);
        if (!mounted) return;
        if (widget.restartAfterResult) {
          unawaited(_startSession());
        }
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
    widget.onCancel?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AiroSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (widget.showHeading) ...[
            Text(
              'Scan with your phone',
              style: AiroTypography.titleLarge.copyWith(
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AiroSpacing.sm),
          ],
          Text(
            'Connect to the same Wi-Fi, scan the code, and type your '
            'playlist link on your phone.',
            style: AiroTypography.bodyMedium.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AiroSpacing.lg),
          _buildBody(theme),
          if (widget.showCancel) ...[
            const SizedBox(height: AiroSpacing.lg),
            TvFocusable(
              key: const ValueKey('tv-playlist-qr-cancel'),
              semanticLabel: 'Cancel',
              autofocus: true,
              onSelect: _cancel,
              borderRadius: AiroSpacing.radiusSm,
              child: OutlinedButton(
                onPressed: _cancel,
                child: const Text('Cancel'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_startError != null) {
      return Text(
        "Couldn't start pairing — check your TV's Wi-Fi connection.",
        key: const ValueKey('tv-playlist-qr-error'),
        style: AiroTypography.bodyMedium.copyWith(
          color: theme.colorScheme.error,
        ),
        textAlign: TextAlign.center,
      );
    }
    if (_status == _PairingStatus.expired) {
      return Column(
        key: const ValueKey('tv-playlist-qr-expired'),
        children: [
          Text(
            'QR code expired',
            style: AiroTypography.titleMedium.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AiroSpacing.md),
          TvFocusable(
            key: const ValueKey('tv-playlist-qr-regenerate'),
            semanticLabel: 'Generate new code',
            onSelect: () => unawaited(_startSession()),
            borderRadius: AiroSpacing.radiusSm,
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
          padding: const EdgeInsets.all(AiroSpacing.md),
          color: Colors.white,
          child: QrImageView(
            data: url.toString(),
            size: 200,
            backgroundColor: Colors.white,
          ),
        ),
        const SizedBox(height: AiroSpacing.md),
        Text(
          'Waiting for your phone…',
          style: AiroTypography.bodySmall.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
