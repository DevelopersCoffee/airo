import 'package:core_ui/core_ui.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_playlist/platform_playlist.dart';

/// Content-source management section (CV-022 + CV-032): list configured
/// sources with their capability flags, add a source of any kind
/// (M3U / Xtream / Stalker / Jellyfin), remove any source with
/// confirmation. The XMLTV guide source is managed by the embedded
/// [XmltvSourceSheet] (a separate concept — EPG data, not a channel/VOD
/// source).
class TvSourceManagementSection extends ConsumerStatefulWidget {
  const TvSourceManagementSection({super.key});

  @override
  ConsumerState<TvSourceManagementSection> createState() =>
      _TvSourceManagementSectionState();
}

class _TvSourceManagementSectionState
    extends ConsumerState<TvSourceManagementSection> {
  bool _showAddForm = false;
  ContentSourceKind _kind = ContentSourceKind.m3u;
  final _labelController = TextEditingController();
  final _urlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _macController = TextEditingController();
  String? _labelError;
  String? _urlError;
  String? _submitError;

  @override
  void dispose() {
    _labelController.dispose();
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _macController.dispose();
    super.dispose();
  }

  void _resetForm() {
    _showAddForm = false;
    _kind = ContentSourceKind.m3u;
    _labelController.clear();
    _urlController.clear();
    _usernameController.clear();
    _passwordController.clear();
    _macController.clear();
    _labelError = null;
    _urlError = null;
    _submitError = null;
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
    setState(_resetForm);
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

    if (_kind == ContentSourceKind.xtream ||
        _kind == ContentSourceKind.jellyfin) {
      final username = _usernameController.text.trim();
      final password = _passwordController.text;
      if (username.isEmpty || password.isEmpty) {
        setState(() => _submitError = 'Username and password are required.');
        return;
      }
    } else if (_kind == ContentSourceKind.stalker) {
      final mac = _macController.text.trim();
      if (mac.isEmpty) {
        setState(() => _submitError = 'MAC address is required.');
        return;
      }
    }

    setState(() {
      _labelError = null;
      _urlError = null;
      _submitError = null;
    });

    try {
      switch (_kind) {
        case ContentSourceKind.m3u:
          await ref.read(
            addM3uContentSourceProvider((label: label, url: url)).future,
          );
        case ContentSourceKind.xtream:
          final username = _usernameController.text;
          final password = _passwordController.text;
          await ref.read(
            addXtreamContentSourceProvider((
              label: label,
              url: url,
              username: username,
              password: password,
            )).future,
          );
        case ContentSourceKind.stalker:
          final mac = _macController.text.trim();
          await ref.read(
            addStalkerContentSourceProvider((
              label: label,
              url: url,
              macAddress: mac,
            )).future,
          );
        case ContentSourceKind.jellyfin:
          final username = _usernameController.text;
          final password = _passwordController.text;
          await ref.read(
            addJellyfinContentSourceProvider((
              label: label,
              url: url,
              username: username,
              password: password,
            )).future,
          );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _submitError = 'Could not add source: $error');
      return;
    }

    if (!mounted) return;
    setState(_resetForm);
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

  String _urlFieldLabel() {
    switch (_kind) {
      case ContentSourceKind.m3u:
        return 'Playlist URL';
      case ContentSourceKind.xtream:
      case ContentSourceKind.jellyfin:
        return 'Server URL';
      case ContentSourceKind.stalker:
        return 'Portal URL';
    }
  }

  String _kindLabel(ContentSourceKind kind) {
    switch (kind) {
      case ContentSourceKind.m3u:
        return 'M3U Playlist';
      case ContentSourceKind.xtream:
        return 'Xtream Codes';
      case ContentSourceKind.stalker:
        return 'Stalker Portal';
      case ContentSourceKind.jellyfin:
        return 'Jellyfin';
    }
  }

  Widget _capabilityBadges(ContentSourceCapabilities caps) {
    final flags = <String>[
      if (caps.hasEpg) 'EPG',
      if (caps.hasVod) 'VOD',
      if (caps.hasCatchup) 'Catch-up',
    ];
    if (flags.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final flag in flags)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white12,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              flag,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
      ],
    );
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
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _kindLabel(config.kind),
                              style: const TextStyle(color: Colors.white70),
                            ),
                            const SizedBox(height: 4),
                            _capabilityBadges(
                              config.toContentSource().capabilities,
                            ),
                          ],
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
              semanticLabel: 'Add Source',
              semanticButton: true,
              child: FilledButton(
                onPressed: _openAddForm,
                child: const Text('Add Source'),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButton<ContentSourceKind>(
                  key: const Key('source-kind-picker'),
                  value: _kind,
                  dropdownColor: Colors.black87,
                  style: const TextStyle(color: Colors.white),
                  onChanged: (kind) {
                    if (kind == null) return;
                    setState(() => _kind = kind);
                  },
                  items: [
                    for (final kind in ContentSourceKind.values)
                      DropdownMenuItem(
                        value: kind,
                        child: Text(_kindLabel(kind)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
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
                  semanticLabel: _urlFieldLabel(),
                  child: TextField(
                    controller: _urlController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: _urlFieldLabel(),
                      border: const OutlineInputBorder(),
                      errorText: _urlError,
                    ),
                  ),
                ),
                if (_kind == ContentSourceKind.xtream ||
                    _kind == ContentSourceKind.jellyfin) ...[
                  const SizedBox(height: 8),
                  TvFocusable(
                    semanticLabel: 'Username',
                    child: TextField(
                      controller: _usernameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TvFocusable(
                    semanticLabel: 'Password',
                    child: TextField(
                      controller: _passwordController,
                      style: const TextStyle(color: Colors.white),
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
                if (_kind == ContentSourceKind.stalker) ...[
                  const SizedBox(height: 8),
                  TvFocusable(
                    semanticLabel: 'MAC Address',
                    child: TextField(
                      controller: _macController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'MAC Address',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
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
