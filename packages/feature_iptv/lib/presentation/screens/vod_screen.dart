import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_ui/core_ui.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_player/platform_player.dart';

import '../../application/providers/iptv_providers.dart';
import '../../application/providers/recently_watched_recorder.dart';
import '../../application/providers/vod_providers.dart';
import '../widgets/vod_list_widget.dart';

/// Phone-oriented VOD screen: a "Continue Watching" row (when non-empty)
/// above [VodListWidget]. Mirrors [IPTVScreen]'s `AiroResponsiveScaffold` +
/// `AppBar` structure for visual consistency with the rest of `feature_iptv`.
class VodScreen extends ConsumerWidget {
  const VodScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final continueWatching =
        ref.watch(vodContinueWatchingProvider).value ?? const [];

    return AiroResponsiveScaffold(
      padding: EdgeInsets.zero,
      appBar: AppBar(title: const Text('Movies & Shows')),
      body: Column(
        children: [
          if (continueWatching.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Continue Watching',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            SizedBox(
              height: 140,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: continueWatching.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final item = continueWatching[index];
                  return SizedBox(
                    width: 160,
                    child: _ContinueWatchingCard(
                      item: item,
                      onTap: () => _selectItem(ref, item),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
          Expanded(
            child: VodListWidget(
              onItemTap: (item) => _selectItem(ref, item),
              onAddSubtitleTap: (item) => _attachSubtitle(context, ref, item),
            ),
          ),
        ],
      ),
    );
  }

  void _selectItem(WidgetRef ref, VodItem item) {
    // VOD streams the same way live channels do (per CV-019): reuse the
    // existing live-channel player by building a minimal synthetic
    // IPTVChannel purely for this call — a same-request, non-persisted,
    // player-launch-only adapter, not a shared/persisted history record.
    final syntheticChannel = IPTVChannel(
      id: item.id,
      name: item.title,
      streamUrl: item.streamUrl,
      logoUrl: item.posterUrl,
      group: item.group,
    );
    ref.read(pendingVodHistoryItemProvider.notifier).state = item;
    ref.read(iptvStreamingServiceProvider).playChannel(syntheticChannel);
  }

  Future<void> _attachSubtitle(
    BuildContext context,
    WidgetRef ref,
    VodItem item,
  ) async {
    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add subtitle URL (optional)'),
          content: TextField(
            key: const ValueKey('vod-subtitle-url-field'),
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'https://example.com/subtitles.vtt',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Attach'),
            ),
          ],
        );
      },
    );
    if (url == null || url.isEmpty) return;

    // Unlike the other .direct() call sites in this codebase (channel/VOD
    // stream URLs resolved internally by provider adapters), this URL is
    // raw user-typed text. .direct() deliberately skips .redacted()'s
    // validation, so nothing else stops a user from pointing this at a
    // local file path or an internal IP — reject anything that isn't a
    // plain http/https URL before it ever reaches the subtitle renderer.
    final uri = Uri.tryParse(url);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enter a valid http:// or https:// subtitle URL.'),
          ),
        );
      }
      return;
    }

    // Reload-to-apply per the engine contract: attaching a subtitle to an
    // already-open source isn't supported (see AiroPlaybackEngine.open()),
    // so this is stored for the *next* open — Task 7's playChannel() reads
    // it. If the item is already playing, the user needs to tap it again
    // for the subtitle to take effect; the dialog copy makes this explicit
    // rather than implying an instant attach.
    ref
        .read(iptvStreamingServiceProvider)
        .attachExternalSubtitle(
          item.id,
          AiroPlaybackExternalSubtitle(
            handle: AiroPlaybackSourceHandle.direct(url),
            label: 'Custom subtitle',
          ),
        );
  }
}

class _ContinueWatchingCard extends StatelessWidget {
  const _ContinueWatchingCard({required this.item, required this.onTap});

  final VodItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: item.title,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.play_circle_fill,
                  color: Theme.of(context).colorScheme.primary,
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  item.title,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
