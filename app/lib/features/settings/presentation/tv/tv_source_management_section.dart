import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Content-source management section (CV-022): list configured sources,
/// add an M3U source, remove any source (with confirmation). The XMLTV
/// guide source (a separate concept — EPG data, not a channel/VOD source)
/// is managed via the embedded [XmltvSourceSheet], built for exactly this
/// purpose in CV-015 slice 2.
class TvSourceManagementSection extends ConsumerStatefulWidget {
  const TvSourceManagementSection({super.key});

  @override
  ConsumerState<TvSourceManagementSection> createState() =>
      _TvSourceManagementSectionState();
}

class _TvSourceManagementSectionState
    extends ConsumerState<TvSourceManagementSection> {
  bool _showAddForm = false;
  final _labelController = TextEditingController();
  final _urlController = TextEditingController();

  @override
  void dispose() {
    _labelController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _addSource() async {
    final label = _labelController.text.trim();
    final url = _urlController.text.trim();
    if (label.isEmpty || url.isEmpty) return;

    await ref.read(
      addM3uContentSourceProvider((label: label, url: url)).future,
    );
    if (!mounted) return;
    setState(() {
      _showAddForm = false;
      _labelController.clear();
      _urlController.clear();
    });
  }

  Future<void> _confirmRemove(ContentSourceConfig config) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove "${config.label}"?'),
        content: const Text(
          'This removes the source and any saved credentials.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(removeContentSourceProvider(config.id).future);
  }

  @override
  Widget build(BuildContext context) {
    final sourcesAsync = ref.watch(configuredContentSourcesProvider);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Content Sources',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 12),
          sourcesAsync.when(
            loading: () => const CircularProgressIndicator(),
            error: (error, _) => Text('Could not load sources: $error'),
            data: (sources) {
              if (sources.isEmpty) {
                return const Text(
                  'No sources configured yet.',
                  style: TextStyle(color: Colors.white70),
                );
              }
              return Column(
                children: [
                  for (final config in sources)
                    ListTile(
                      title: Text(
                        config.label,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        config.kind.stableId,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.white,
                        ),
                        onPressed: () => _confirmRemove(config),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          if (!_showAddForm)
            FilledButton(
              onPressed: () => setState(() => _showAddForm = true),
              child: const Text('Add M3U Source'),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _labelController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Label',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _urlController,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    labelText: 'Playlist URL',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    FilledButton(
                      onPressed: _addSource,
                      child: const Text('Save'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => setState(() => _showAddForm = false),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ],
            ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          const XmltvSourceSheet(),
        ],
      ),
    );
  }
}
