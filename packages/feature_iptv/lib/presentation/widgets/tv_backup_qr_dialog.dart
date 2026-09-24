import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_playlist_export/platform_playlist_export.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../application/providers/tv_lan_backup_providers.dart';
import '../../application/services/tv_lan_backup_export_server.dart';
import '../../application/services/tv_lan_backup_import_server.dart';

class TvBackupExportQrDialog extends StatelessWidget {
  const TvBackupExportQrDialog({super.key, required this.document});

  final AiroBackupDocument document;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: TvBackupExportQrPanel(
          document: document,
          onDismiss: (available) => Navigator.of(context).pop(available),
        ),
      ),
    );
  }
}

class TvBackupImportQrDialog extends StatelessWidget {
  const TvBackupImportQrDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: TvBackupImportQrPanel(
          onDocumentReceived: (document) => Navigator.of(context).pop(document),
          onCancel: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
}

enum _SessionStatus { waiting, expired }

class TvBackupExportQrPanel extends ConsumerStatefulWidget {
  const TvBackupExportQrPanel({
    super.key,
    required this.document,
    required this.onDismiss,
  });

  final AiroBackupDocument document;
  final ValueChanged<bool> onDismiss;

  @override
  ConsumerState<TvBackupExportQrPanel> createState() =>
      _TvBackupExportQrPanelState();
}

class _TvBackupExportQrPanelState extends ConsumerState<TvBackupExportQrPanel> {
  TvLanBackupExportServer? _server;
  Uri? _sessionUrl;
  _SessionStatus _status = _SessionStatus.waiting;
  Object? _startError;
  var _sessionAvailable = false;

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

    final server = ref.read(tvLanBackupExportServerFactoryProvider)(
      widget.document,
    );
    setState(() {
      _server = server;
      _sessionUrl = null;
      _status = _SessionStatus.waiting;
      _startError = null;
      _sessionAvailable = false;
    });

    try {
      final url = await server.start();
      if (!mounted) return;
      setState(() {
        _sessionUrl = url;
        _sessionAvailable = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _startError = error);
    }
  }

  void _cancel() {
    unawaited(_server?.stop());
    widget.onDismiss(_sessionAvailable);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AiroSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Download backup on your phone',
            style: AiroTypography.titleLarge.copyWith(
              color: theme.colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AiroSpacing.sm),
          Text(
            'Connect to the same Wi-Fi, scan the code, and download the '
            'backup file on your phone.',
            style: AiroTypography.bodyMedium.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AiroSpacing.lg),
          _buildBody(theme),
          const SizedBox(height: AiroSpacing.lg),
          TvFocusable(
            key: const ValueKey('tv-backup-export-cancel'),
            semanticLabel: 'Close',
            autofocus: true,
            onSelect: _cancel,
            borderRadius: AiroSpacing.radiusSm,
            child: OutlinedButton(
              onPressed: _cancel,
              child: const Text('Close'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_startError != null) {
      return Text(
        "Couldn't start backup transfer — check your TV's Wi-Fi connection.",
        key: const ValueKey('tv-backup-export-error'),
        style: AiroTypography.bodyMedium.copyWith(
          color: theme.colorScheme.error,
        ),
        textAlign: TextAlign.center,
      );
    }
    if (_status == _SessionStatus.expired) {
      return Column(
        key: const ValueKey('tv-backup-export-expired'),
        children: [
          Text(
            'QR code expired',
            style: AiroTypography.titleMedium.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AiroSpacing.md),
          TvFocusable(
            key: const ValueKey('tv-backup-export-regenerate'),
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
    final url = _sessionUrl;
    if (url == null) {
      return const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Column(
      key: const ValueKey('tv-backup-export-waiting'),
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
          'Ready to download on your phone',
          style: AiroTypography.bodySmall.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class TvBackupImportQrPanel extends ConsumerStatefulWidget {
  const TvBackupImportQrPanel({
    super.key,
    required this.onDocumentReceived,
    required this.onCancel,
  });

  final ValueChanged<AiroBackupDocument> onDocumentReceived;
  final VoidCallback onCancel;

  @override
  ConsumerState<TvBackupImportQrPanel> createState() =>
      _TvBackupImportQrPanelState();
}

class _TvBackupImportQrPanelState extends ConsumerState<TvBackupImportQrPanel> {
  TvLanBackupImportServer? _server;
  Uri? _sessionUrl;
  _SessionStatus _status = _SessionStatus.waiting;
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

    final server = ref.read(tvLanBackupImportServerFactoryProvider)();
    setState(() {
      _server = server;
      _sessionUrl = null;
      _status = _SessionStatus.waiting;
      _startError = null;
    });

    try {
      final url = await server.start();
      if (!mounted) return;
      setState(() => _sessionUrl = url);
      final document = await server.result;
      if (!mounted) return;
      if (document != null) {
        widget.onDocumentReceived(document);
        return;
      }
      setState(() => _status = _SessionStatus.expired);
    } catch (error) {
      if (!mounted) return;
      setState(() => _startError = error);
    }
  }

  void _cancel() {
    unawaited(_server?.stop());
    widget.onCancel();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AiroSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Send backup from your phone',
            style: AiroTypography.titleLarge.copyWith(
              color: theme.colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AiroSpacing.sm),
          Text(
            'Connect to the same Wi-Fi, scan the code, and upload your '
            'saved backup JSON on your phone.',
            style: AiroTypography.bodyMedium.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AiroSpacing.lg),
          _buildBody(theme),
          const SizedBox(height: AiroSpacing.lg),
          TvFocusable(
            key: const ValueKey('tv-backup-import-cancel'),
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
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_startError != null) {
      return Text(
        "Couldn't start backup upload — check your TV's Wi-Fi connection.",
        key: const ValueKey('tv-backup-import-error'),
        style: AiroTypography.bodyMedium.copyWith(
          color: theme.colorScheme.error,
        ),
        textAlign: TextAlign.center,
      );
    }
    if (_status == _SessionStatus.expired) {
      return Column(
        key: const ValueKey('tv-backup-import-expired'),
        children: [
          Text(
            'QR code expired',
            style: AiroTypography.titleMedium.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AiroSpacing.md),
          TvFocusable(
            key: const ValueKey('tv-backup-import-regenerate'),
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
    final url = _sessionUrl;
    if (url == null) {
      return const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Column(
      key: const ValueKey('tv-backup-import-waiting'),
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
