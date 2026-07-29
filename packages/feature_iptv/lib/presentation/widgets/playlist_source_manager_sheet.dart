import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_playlist/platform_playlist.dart';

import '../../application/content_source_store.dart';
import '../../application/providers/content_source_management_providers.dart';
import '../../application/providers/iptv_providers.dart';

class IptvOrgPlaylistPreset {
  const IptvOrgPlaylistPreset({required this.label, required this.url});

  final String label;
  final String url;
}

const iptvOrgPlaylistPresets = <IptvOrgPlaylistPreset>[
  IptvOrgPlaylistPreset(
    label: 'All channels',
    url: 'https://iptv-org.github.io/iptv/index.m3u',
  ),
  IptvOrgPlaylistPreset(
    label: 'By category',
    url: 'https://iptv-org.github.io/iptv/index.category.m3u',
  ),
  IptvOrgPlaylistPreset(
    label: 'By language',
    url: 'https://iptv-org.github.io/iptv/index.language.m3u',
  ),
  IptvOrgPlaylistPreset(
    label: 'By country',
    url: 'https://iptv-org.github.io/iptv/index.country.m3u',
  ),
];

/// Touch-first playlist manager for phone and tablet surfaces.
///
/// The source list is deliberately M3U-only: Xtream, Stalker, Jellyfin, and
/// XMLTV remain in their existing settings flows. Source URLs are shown
/// without query strings so credential-like tokens are not exposed on screen.
class PlaylistSourceManagerSheet extends ConsumerStatefulWidget {
  const PlaylistSourceManagerSheet({super.key, this.initialUrl});

  final String? initialUrl;

  @override
  ConsumerState<PlaylistSourceManagerSheet> createState() =>
      _PlaylistSourceManagerSheetState();
}

class _PlaylistSourceManagerSheetState
    extends ConsumerState<PlaylistSourceManagerSheet> {
  final _labelController = TextEditingController();
  final _urlController = TextEditingController();
  bool _showAddForm = false;
  bool _isSaving = false;
  String? _labelError;
  String? _urlError;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    final initialUrl = widget.initialUrl?.trim();
    if (initialUrl != null && initialUrl.isNotEmpty) {
      _showAddForm = true;
      _urlController.text = initialUrl;
    }
  }

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
      _labelController.clear();
      _urlController.clear();
      _labelError = null;
      _urlError = null;
      _submitError = null;
    });
  }

  void _selectPreset(IptvOrgPlaylistPreset preset) {
    setState(() {
      _showAddForm = true;
      _labelController.text = 'IPTV.org · ${preset.label}';
      _urlController.text = preset.url;
      _labelError = null;
      _urlError = null;
      _submitError = null;
    });
  }

  String? _validateUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.host.isEmpty ||
        !(uri.isScheme('http') || uri.isScheme('https'))) {
      return 'Enter a valid http:// or https:// playlist URL.';
    }
    return null;
  }

  Future<void> _addSource() async {
    final label = _labelController.text.trim();
    final url = _urlController.text.trim();
    final labelError = label.isEmpty ? 'Enter a name for this playlist.' : null;
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
      _isSaving = true;
      _labelError = null;
      _urlError = null;
      _submitError = null;
    });
    try {
      await ref.read(
        addM3uContentSourceProvider((label: label, url: url)).future,
      );
      if (!mounted) return;
      _closeAddForm();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$label added. Channels are refreshing.')),
      );
    } on DuplicatePlaylistSourceException {
      if (!mounted) return;
      setState(() => _submitError = 'This playlist is already in your list.');
    } on ArgumentError catch (error) {
      if (!mounted) return;
      setState(() => _submitError = error.message.toString());
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitError = 'Could not add this playlist. Try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _removeSource(ContentSourceConfig source) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove "${source.label}"?'),
        content: const Text(
          'Other playlist sources and their channels will stay available.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(removeContentSourceProvider(source.id).future);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not remove the playlist.')),
      );
    }
  }

  String _safeLocation(String rawUrl) {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || uri.host.isEmpty) return 'M3U playlist';
    final path = uri.path.isEmpty ? '/' : uri.path;
    return '${uri.host}$path';
  }

  @override
  Widget build(BuildContext context) {
    final sourcesAsync = ref.watch(configuredContentSourcesProvider);
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + viewInsets.bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Playlist sources',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close playlist sources',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Combine multiple authorized M3U playlists. Duplicate '
                  'channels are merged automatically.',
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                sourcesAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (_, _) => const Text(
                    'Could not load playlist sources. Try reopening this panel.',
                  ),
                  data: (allSources) {
                    final sources = allSources
                        .where((source) => source.kind == ContentSourceKind.m3u)
                        .toList(growable: false);
                    if (sources.isEmpty) {
                      return DecoratedBox(
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'No playlists yet. Add a URL to start watching.',
                          ),
                        ),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '${sources.length} playlist '
                          'source${sources.length == 1 ? '' : 's'}',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        for (final source in sources)
                          Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              minTileHeight: 64,
                              leading: const Icon(Icons.playlist_play),
                              title: Text(source.label),
                              subtitle: Text(
                                _safeLocation(source.url),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: SizedBox.square(
                                dimension: 48,
                                child: IconButton(
                                  tooltip: 'Remove ${source.label}',
                                  constraints: const BoxConstraints(
                                    minWidth: 48,
                                    minHeight: 48,
                                  ),
                                  onPressed: () => _removeSource(source),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                if (!_showAddForm)
                  SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      key: const ValueKey('playlist-source-add-button'),
                      onPressed: _openAddForm,
                      icon: const Icon(Icons.add),
                      label: const Text('Add playlist source'),
                    ),
                  )
                else
                  _buildAddForm(context),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAddForm(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add playlist',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Paste any M3U URL, including category, language, country, '
              'region, city, or source playlists from IPTV.org.',
            ),
            const SizedBox(height: 12),
            Text(
              'IPTV.org quick choices',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final preset in iptvOrgPlaylistPresets)
                  ActionChip(
                    label: Text(preset.label),
                    onPressed: _isSaving ? null : () => _selectPreset(preset),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('playlist-source-label-field'),
              controller: _labelController,
              enabled: !_isSaving,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Playlist name',
                hintText: 'India news',
                errorText: _labelError,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('playlist-source-url-field'),
              controller: _urlController,
              enabled: !_isSaving,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _isSaving ? null : _addSource(),
              decoration: InputDecoration(
                labelText: 'M3U playlist URL',
                hintText: 'https://example.com/playlist.m3u',
                errorText: _urlError,
                prefixIcon: const Icon(Icons.link),
                border: const OutlineInputBorder(),
              ),
            ),
            if (_submitError != null) ...[
              const SizedBox(height: 8),
              Text(_submitError!, style: TextStyle(color: colorScheme.error)),
            ],
            const SizedBox(height: 12),
            if (_isSaving) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 12),
            ],
            OverflowBar(
              alignment: MainAxisAlignment.end,
              spacing: 8,
              overflowSpacing: 8,
              children: [
                SizedBox(
                  height: 48,
                  child: TextButton(
                    onPressed: _isSaving ? null : _closeAddForm,
                    child: const Text('Cancel'),
                  ),
                ),
                SizedBox(
                  height: 48,
                  child: FilledButton.icon(
                    key: const ValueKey('playlist-source-save-button'),
                    onPressed: _isSaving ? null : _addSource,
                    icon: const Icon(Icons.add),
                    label: Text(_isSaving ? 'Adding…' : 'Add source'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
