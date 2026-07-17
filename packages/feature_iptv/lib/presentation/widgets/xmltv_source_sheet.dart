import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/guide_providers.dart';

/// Lets the user add, refresh, or remove the single configured XMLTV
/// guide source. A ready-to-use widget — CV-022 (TV settings screen, not
/// yet built) is expected to present this via `showModalBottomSheet` or
/// embed it directly; this task only builds and tests the widget itself.
class XmltvSourceSheet extends ConsumerStatefulWidget {
  const XmltvSourceSheet({super.key});

  @override
  ConsumerState<XmltvSourceSheet> createState() => _XmltvSourceSheetState();
}

class _XmltvSourceSheetState extends ConsumerState<XmltvSourceSheet> {
  final _urlController = TextEditingController();
  bool _isRefreshing = false;
  String? _refreshFeedback;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _saveAndRefresh() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isRefreshing = true;
      _refreshFeedback = null;
    });

    try {
      await ref.read(xmltvSourceRefreshServiceProvider).refresh(url);
      if (!mounted) return;
      setState(() => _refreshFeedback = 'Guide refreshed.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _refreshFeedback = 'Refresh failed: $e');
    } finally {
      if (!mounted) return;
      setState(() => _isRefreshing = false);
      ref.invalidate(xmltvSourceConfigProvider);
    }
  }

  Future<void> _removeSource() async {
    await ref.read(xmltvSourceStoreProvider).clear();
    if (!mounted) return;
    ref.invalidate(xmltvSourceConfigProvider);
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(xmltvSourceConfigProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('XMLTV Guide Source', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          configAsync.when(
            loading: () => const CircularProgressIndicator(),
            error: (error, _) => Text('Could not load source config: $error'),
            data: (config) {
              if (config == null) {
                return const Text('No XMLTV source configured yet.');
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Current source: ${config.url}'),
                  const SizedBox(height: 4),
                  Text(
                    config.lastRefreshedAt != null
                        ? 'Last refreshed: ${config.lastRefreshedAt}'
                        : 'Never refreshed successfully.',
                  ),
                  if (config.lastError != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      config.lastError!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  TextButton(onPressed: _removeSource, child: const Text('Remove source')),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: 'XMLTV URL',
              hintText: 'https://example.com/guide.xml',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _isRefreshing ? null : _saveAndRefresh,
            child: _isRefreshing
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save & Refresh'),
          ),
          if (_refreshFeedback != null) ...[
            const SizedBox(height: 8),
            Text(_refreshFeedback!),
          ],
        ],
      ),
    );
  }
}
