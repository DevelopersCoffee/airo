import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/portability/airo_backup_service.dart';

/// Encrypted export/import for Airo Mind configuration and model metadata.
class AiroPortabilityScreen extends StatefulWidget {
  const AiroPortabilityScreen({super.key});

  @override
  State<AiroPortabilityScreen> createState() => _AiroPortabilityScreenState();
}

class _AiroPortabilityScreenState extends State<AiroPortabilityScreen> {
  final _passphraseController = TextEditingController();
  final _service = AiroBackupService();
  bool _busy = false;
  String? _status;

  @override
  void dispose() {
    _passphraseController.dispose();
    super.dispose();
  }

  Future<void> _export() async {
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = await _service.writeExport(
        directory: Directory('${directory.path}/exports'),
        passphrase: _passphraseController.text,
        payload: {
          'scope': 'airo-mind',
          'exportedAt': DateTime.now().toUtc().toIso8601String(),
          'note':
              'Model metadata and local preferences only; model weights are not copied.',
        },
      );
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)]));
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

  Future<void> _import() async {
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['airobackup'],
      );
      final path = result?.files.single.path;
      if (path == null) return;
      final payload = await _service.decrypt(
        await File(path).readAsString(),
        _passphraseController.text,
      );
      if (mounted) {
        setState(
          () => _status =
              'Backup verified (${payload['scope'] ?? 'Airo'}). Import is ready for review.',
        );
      }
    } catch (error) {
      if (mounted) setState(() => _status = 'Import failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
