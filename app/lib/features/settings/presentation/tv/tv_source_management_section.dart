import 'package:core_ui/core_ui.dart';
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
  String? _labelError;
  String? _urlError;
  String? _submitError;

  @override
  void dispose() {
    _labelController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  void _openAddForm() {
    setState(() {
      _showAddForm = true;
      _labelError = null;
      _urlError = null;
      _submitError = null;
    });
  }

  void _closeAddForm() {
    setState(() {
      _showAddForm = false;
      _labelError = null;
      _urlError = null;
      _submitError = null;
    });
  }

  /// Accepts only well-formed http/https URLs — the M3U fetcher can't do
  /// anything useful with anything else, and a bad URL persisted silently
  /// is worse than an inline error asking the user to fix it now.
  String? _validateUrl(String url) {
    if (url.isEmpty) return 'Enter a playlist URL.';
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !uri.hasScheme ||
        !(uri.isScheme('http') || uri.isScheme('https'))) {
      return 'Enter a valid http:// or https:// URL.';
    }
    return null;
  }

  Future<void> _addSource() async {
    final label = _labelController.text.trim();
    final url = _urlController.text.trim();

    final labelError = label.isEmpty ? 'Enter a label.' : null;
    final urlError = _validateUrl(url);

    if (labelError != null || urlError != null) {
      setState(() {
        _labelError = labelError;
        _urlError = urlError;
        _submitError = null;
      });
      return;
    }

    setState(() {
      _labelError = null;
      _urlError = null;
      _submitError = null;
    });

    try {
      await ref.read(
        addM3uContentSourceProvider((label: label, url: url)).future,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitError = 'Could not add source: $error');
      return;
    }

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
          TvFocusable(
            onSelect: () => Navigator.of(context).pop(false),
            semanticLabel: 'Cancel',
            semanticButton: true,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
          ),
          TvFocusable(
            onSelect: () => Navigator.of(context).pop(true),
            semanticLabel: 'Remove',
            semanticButton: true,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Remove'),
            ),
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
                    TvFocusable(
                      semanticLabel: config.label,
                      child: ListTile(
                        title: Text(
                          config.label,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          config.kind.stableId,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        trailing: TvFocusable(
                          onSelect: () => _confirmRemove(config),
                          semanticLabel: 'Remove ${config.label}',
                          semanticButton: true,
                          child: IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.white,
                            ),
                            onPressed: () => _confirmRemove(config),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          if (!_showAddForm)
            TvFocusable(
              onSelect: _openAddForm,
              semanticLabel: 'Add M3U Source',
              semanticButton: true,
              child: FilledButton(
                onPressed: _openAddForm,
                child: const Text('Add M3U Source'),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TvFocusable(
                  semanticLabel: 'Label',
                  child: TextField(
                    controller: _labelController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Label',
                      border: const OutlineInputBorder(),
                      errorText: _labelError,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TvFocusable(
                  semanticLabel: 'Playlist URL',
                  child: TextField(
                    controller: _urlController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Playlist URL',
                      border: const OutlineInputBorder(),
                      errorText: _urlError,
                    ),
                  ),
                ),
                if (_submitError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _submitError!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    TvFocusable(
                      onSelect: _addSource,
                      semanticLabel: 'Save',
                      semanticButton: true,
                      child: FilledButton(
                        onPressed: _addSource,
                        child: const Text('Save'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TvFocusable(
                      onSelect: _closeAddForm,
                      semanticLabel: 'Cancel',
                      semanticButton: true,
                      child: TextButton(
                        onPressed: _closeAddForm,
                        child: const Text('Cancel'),
                      ),
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
