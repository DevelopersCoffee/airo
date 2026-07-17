import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_ui/core_ui.dart';
import 'package:platform_channels/platform_channels.dart';

import '../../application/providers/iptv_providers.dart';
import '../../application/providers/vod_providers.dart';
import '../widgets/vod_grid.dart';

/// A 10-foot VOD experience for Android TV and Fire TV: a "Continue
/// Watching" row (when non-empty) above [VodGrid]. Mirrors
/// [IptvTvScreen]'s dark, full-bleed layout since both screens live in the
/// same TV shell.
class VodTvScreen extends ConsumerWidget {
  const VodTvScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final continueWatching =
        ref.watch(vodContinueWatchingProvider).value ?? const [];

    return AiroResponsiveScaffold(
      overrideFormFactor: AiroFormFactor.tv,
      padding: EdgeInsets.zero,
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (continueWatching.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Text(
                  'Continue Watching',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              SizedBox(
                height: 150,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: continueWatching.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 16),
                  itemBuilder: (context, index) {
                    final item = continueWatching[index];
                    return SizedBox(
                      width: 200,
                      child: _ContinueWatchingTile(
                        item: item,
                        onSelect: () => _selectItem(ref, item),
                      ),
                    );
                  },
                ),
              ),
            ],
            Expanded(
              child: VodGrid(onItemSelect: (item) => _selectItem(ref, item)),
            ),
          ],
        ),
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

class _ContinueWatchingTile extends StatelessWidget {
  const _ContinueWatchingTile({required this.item, required this.onSelect});

  final VodItem item;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      onSelect: onSelect,
      semanticLabel: item.title,
      semanticHint: 'Press OK to resume',
      semanticButton: true,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey[850],
          borderRadius: BorderRadius.circular(TvFocusConstants.focusBorderRadius),
        ),
        child: Center(
          child: Text(
            item.title,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}
