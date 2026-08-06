import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:core_ai/core_ai.dart';
import 'package:feature_assistant/feature_assistant.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/portability/airo_backup_service.dart';
import '../../../../core/portability/airo_lan_sync_service.dart';
import '../../../../core/portability/airo_portability_codec.dart';

/// Encrypted export/import for Airo Mind configuration and model metadata.
class AiroPortabilityScreen extends StatefulWidget {
  const AiroPortabilityScreen({
    super.key,
    this.getDocumentsDirectory,
    this.pickBackupPath,
    this.shareExportPath,
    this.readBackupContent,
    this.backupService,
    this.buildPayload,
    this.encodePayload,
    this.encodeChatHistory,
  });

  final Future<Directory> Function()? getDocumentsDirectory;
  final Future<String?> Function()? pickBackupPath;
  final Future<void> Function(String path)? shareExportPath;
  final Future<String> Function(String path)? readBackupContent;
  final AiroBackupService? backupService;
  final Future<Map<String, Object?>> Function()? buildPayload;
  final Future<String> Function(Map<String, Object?> payload)? encodePayload;
  final Future<String> Function(
    List<Object?> entries, {
    required int schemaVersion,
  })?
  encodeChatHistory;

  @override
  State<AiroPortabilityScreen> createState() => _AiroPortabilityScreenState();
}

class _AiroPortabilityScreenState extends State<AiroPortabilityScreen> {
  static const _restoredPayloadKey = 'airo_mind.backup_payload.v1';
  final _passphraseController = TextEditingController();
  final _lanUrlController = TextEditingController();
  final _lanService = AiroLanSyncService();
  AiroLanShare? _lanShare;
  bool _busy = false;
  String? _status;

  AiroBackupService get _service => widget.backupService ?? AiroBackupService();

  @override
  void dispose() {
    _passphraseController.dispose();
    _lanUrlController.dispose();
    unawaited(_lanShare?.close());
    super.dispose();
  }

  Future<Map<String, Object?>> _payload() async {
    final payloadBuilder = widget.buildPayload;
    if (payloadBuilder != null) return payloadBuilder();
    final preferences = await SharedPreferences.getInstance();
    Object? chatHistory;
    final encodedHistory = preferences.getString(ChatHistoryStore.storageKey);
    chatHistory = await AiroPortabilityCodec.decodeChatHistory(encodedHistory);
    return {
      'scope': 'airo-mind',
      'schemaVersion': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'modelCatalogIds': ModelCatalog.bundledModels
          .map((model) => model.id)
          .toList(),
      'chatHistory': chatHistory is List ? chatHistory : const [],
      'privacy': 'local-first',
      'note':
          'Model metadata and local preferences only; model weights are not copied.',
    };
  }

  Future<void> _export() async {
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final directory =
          await widget.getDocumentsDirectory?.call() ??
          await getApplicationDocumentsDirectory();
      final file = await _service.writeExport(
        directory: Directory('${directory.path}/exports'),
        passphrase: _passphraseController.text,
        payload: await _payload(),
      );
      final shareExportPath = widget.shareExportPath;
      if (shareExportPath != null) {
        await shareExportPath(file.path);
      } else {
        await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
      }
      if (mounted) {
        setState(
          () => _status = 'Encrypted backup created and ready to share.',
        );
      }
    } catch (error) {
      if (mounted) setState(() => _status = 'Export failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createLanShare() async {
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final encoded = await _service.encrypt(
        await _payload(),
        _passphraseController.text,
      );
      await _lanShare?.close();
      final share = await _lanService.createShare(encoded);
      if (!mounted) {
        await share.close();
        return;
      }
      setState(() {
        _lanShare = share;
        _lanUrlController.text = share.uri.toString();
        _status =
            'Encrypted LAN share ready. Keep both devices on the same Wi-Fi network.';
      });
    } catch (error) {
      if (mounted) setState(() => _status = 'LAN share failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importLanShare() async {
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final uri = Uri.tryParse(_lanUrlController.text.trim());
      if (uri == null) {
        throw const FormatException('Enter a valid LAN share URL');
      }
      final encoded = await _lanService.fetchShare(uri);
      final payload = await _service.decrypt(
        encoded,
        _passphraseController.text,
      );
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        _restoredPayloadKey,
        await _encodePayload(payload),
      );
      await _restoreChatHistoryPayload(preferences, payload);
      if (mounted) {
        setState(
          () => _status =
              'Encrypted LAN backup verified and restored. Restart Airo Mind to apply it.',
        );
      }
    } catch (error) {
      if (mounted) setState(() => _status = 'LAN import failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreChatHistoryPayload(
    SharedPreferences preferences,
    Map<String, Object?> payload,
  ) async {
    final entries = payload['chatHistory'];
    if (entries is! List) return;
    await preferences.setString(
      ChatHistoryStore.storageKey,
      await _encodeChatHistory(
        List<Object?>.from(entries),
        schemaVersion: ChatHistoryStore.schemaVersion,
      ),
    );
  }

  Future<void> _import() async {
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final path =
          await widget.pickBackupPath?.call() ??
          (await FilePicker.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['airobackup'],
          ))?.files.single.path;
      if (path == null) return;
      final encoded =
          await widget.readBackupContent?.call(path) ??
          await File(path).readAsString();
      final payload = await _service.decrypt(
        encoded,
        _passphraseController.text,
      );
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        _restoredPayloadKey,
        await _encodePayload(payload),
      );
      await _restoreChatHistoryPayload(preferences, payload);
      if (mounted) {
        setState(
          () => _status =
              'Backup verified and restored (${payload['scope'] ?? 'Airo'}). Restart Airo Mind to apply model preferences.',
        );
      }
    } catch (error) {
      if (mounted) setState(() => _status = 'Import failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String> _encodePayload(Map<String, Object?> payload) {
    return widget.encodePayload?.call(payload) ??
        AiroPortabilityCodec.encodePayload(payload);
  }

  Future<String> _encodeChatHistory(
    List<Object?> entries, {
    required int schemaVersion,
  }) {
    return widget.encodeChatHistory?.call(
          entries,
          schemaVersion: schemaVersion,
        ) ??
        AiroPortabilityCodec.encodeChatHistory(
          entries,
          schemaVersion: schemaVersion,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Airo Mind Portability')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            child: ListTile(
              leading: Icon(Icons.lock_outline),
              title: Text('Encrypted export and import'),
              subtitle: Text(
                'Passphrases protect your local configuration. Model weight files are never copied into a backup.',
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _passphraseController,
            obscureText: true,
            enabled: !_busy,
            decoration: const InputDecoration(
              labelText: 'Backup passphrase',
              helperText:
                  'At least 8 characters. You must remember it to restore.',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _export,
            icon: const Icon(Icons.ios_share),
            label: const Text('Export encrypted backup'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : _import,
            icon: const Icon(Icons.file_open_outlined),
            label: const Text('Verify and import backup'),
          ),
          const SizedBox(height: 20),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.wifi_tethering),
            title: Text('Encrypted local LAN sync'),
            subtitle: Text(
              'Transfer this encrypted backup directly between devices on the same Wi-Fi network. The share expires automatically.',
            ),
          ),
          FilledButton.tonalIcon(
            onPressed: _busy ? null : _createLanShare,
            icon: const Icon(Icons.qr_code_2),
            label: const Text('Create LAN share'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _lanUrlController,
            enabled: !_busy,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'LAN share URL',
              hintText: 'http://192.168.x.x:port/airo-sync/…',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _busy ? null : _importLanShare,
            icon: const Icon(Icons.download_for_offline_outlined),
            label: const Text('Import from LAN share'),
          ),
          if (_busy) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
          if (_status != null) ...[
            const SizedBox(height: 16),
            Semantics(liveRegion: true, child: Text(_status!)),
          ],
        ],
      ),
    );
  }
}
