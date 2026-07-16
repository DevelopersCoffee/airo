import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_ui/core_ui.dart';
import 'package:platform_channels/platform_channels.dart';

import '../../application/providers/iptv_providers.dart';
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
            child: VodListWidget(onItemTap: (item) => _selectItem(ref, item)),
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
    ref.read(iptvStreamingServiceProvider).playChannel(syntheticChannel);
    ref.read(addToVodWatchHistoryProvider(item).future);
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
