import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef AiroTvChangelogLoader = Future<String> Function();

Future<String> loadAiroTvChangelog() {
  return rootBundle.loadString('packages/feature_iptv/CHANGELOG.md');
}

Future<void> showAiroTvShellHelpDialog(
  BuildContext context, {
  AiroTvChangelogLoader changelogLoader = loadAiroTvChangelog,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => AiroTvShellHelpDialog(changelogLoader: changelogLoader),
  );
}

class AiroTvShellHelpDialog extends StatelessWidget {
  const AiroTvShellHelpDialog({
    super.key,
    this.changelogLoader = loadAiroTvChangelog,
  });

  final AiroTvChangelogLoader changelogLoader;

  static const _helpEntries = [
    (
      'Ways to Watch',
      'Choose fitted, fullscreen, supported floating-window, or Cast playback.',
    ),
    (
      'Filters',
      'Combine search, category, country, and language to narrow channels.',
    ),
    (
      'Hotbar',
      'Keep pinned channel and filter combinations within quick reach.',
    ),
    (
      'Playback Stats',
      'Shows only codec, resolution, and bitrate reported by the active player.',
    ),
    (
      'Explorer rows',
      'Use the settings action to show or hide shell rows for this device.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey('airo-tv-shell-help-dialog'),
      title: const Text('Midas Stream Help'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final entry in _helpEntries)
                ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: Text(entry.$1),
                  subtitle: Text(entry.$2),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TvFocusable(
          semanticLabel: "What's New",
          onSelect: () => _showWhatsNew(context),
          child: TextButton.icon(
            key: const ValueKey('airo-tv-whats-new-action'),
            onPressed: () => _showWhatsNew(context),
            icon: const Icon(Icons.new_releases_outlined),
            label: const Text("What's New"),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Future<void> _showWhatsNew(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => AiroTvWhatsNewDialog(changelogLoader: changelogLoader),
    );
  }
}

class AiroTvWhatsNewDialog extends StatelessWidget {
  const AiroTvWhatsNewDialog({
    super.key,
    this.changelogLoader = loadAiroTvChangelog,
  });

  final AiroTvChangelogLoader changelogLoader;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey('airo-tv-whats-new-dialog'),
      title: const Text("What's New"),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 480),
        child: FutureBuilder<AiroTvReleaseNotes>(
          future: changelogLoader().then(AiroTvReleaseNotes.parseLatest),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Text('Release notes are unavailable.');
            }
            final notes = snapshot.data;
            if (notes == null) {
              return const Center(child: CircularProgressIndicator());
            }
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    notes.version,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  for (final item in notes.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('• $item'),
                    ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

class AiroTvReleaseNotes {
  const AiroTvReleaseNotes({required this.version, required this.items});

  final String version;
  final List<String> items;

  static AiroTvReleaseNotes parseLatest(String changelog) {
    final lines = changelog.split('\n');
    String? version;
    final items = <String>[];
    for (final line in lines) {
      if (line.startsWith('## ')) {
        if (version != null) break;
        version = line.substring(3).trim();
        continue;
      }
      if (version != null && line.startsWith('- ')) {
        items.add(line.substring(2).trim());
      }
    }
    return AiroTvReleaseNotes(
      version: version ?? 'Current release',
      items: List.unmodifiable(
        items.isEmpty ? const ['No release notes available.'] : items,
      ),
    );
  }
}
