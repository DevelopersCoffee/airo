import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_ui/core_ui.dart';
import 'package:platform_channels/platform_channels.dart';

import '../../application/providers/iptv_providers.dart';
import '../../application/providers/recently_watched_recorder.dart';
import '../../application/providers/vod_providers.dart';
import '../tv_ux/widgets/tv_continue_watching_scaffold.dart';
import '../widgets/vod_grid.dart';

/// A 10-foot VOD experience for Android TV and Fire TV: a "Continue
/// Watching" row (when non-empty) above [VodGrid]. Mirrors the live TV
/// path's dark, full-bleed layout (`AiroTvShell` in `tv_ux/`) since both
/// screens live in the same TV shell.
class VodTvScreen extends ConsumerStatefulWidget {
  const VodTvScreen({super.key, this.onItemSelected});

  /// Invoked after an item starts playing, so a shell that paints this
  /// screen as an overlay on top of retained playback can dismiss itself
  /// and reveal the video. Null when the screen owns the whole route.
  final VoidCallback? onItemSelected;

  @override
  ConsumerState<VodTvScreen> createState() => _VodTvScreenState();
}

class _VodTvScreenState extends ConsumerState<VodTvScreen> {
  var _showRemoveHint = false;

  @override
  Widget build(BuildContext context) {
    final continueWatching =
        ref.watch(vodContinueWatchingEntriesProvider).value ?? const [];

    return AiroResponsiveScaffold(
      overrideFormFactor: AiroFormFactor.tv,
      padding: EdgeInsets.zero,
      backgroundColor: Colors.black,
      body: SafeArea(
        child: TvContinueWatchingScaffold(
          showRemoveHint: _showRemoveHint,
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
                  height: MediaCard.railHeightFor(
                    MediaCardVariant.continueWatching,
                  ),
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: continueWatching.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 16),
                    itemBuilder: (context, index) {
                      final entry = continueWatching[index];
                      return SizedBox(
                        width: 172,
                        child: MediaCard(
                          name: entry.item.title,
                          subtitle: entry.item.group,
                          logoUrl: entry.item.posterUrl,
                          variant: MediaCardVariant.continueWatching,
                          showResumeBadge: true,
                          watchProgress: entry.watchProgress,
                          selectLongPressForSecondary: true,
                          onTap: () => _selectItem(ref, entry.item),
                          onLongPress: () => _remove(entry.item.id),
                          onFocus: () =>
                              setState(() => _showRemoveHint = true),
                          onUnfocus: () =>
                              setState(() => _showRemoveHint = false),
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
      ),
    );
  }

  Future<void> _remove(String itemId) async {
    await ref.read(removeFromVodContinueWatchingProvider(itemId).future);
    if (!mounted) return;
    setState(() => _showRemoveHint = false);
  }

  void _selectItem(WidgetRef ref, VodItem item) {
    final syntheticChannel = IPTVChannel(
      id: item.id,
      name: item.title,
      streamUrl: item.streamUrl,
      logoUrl: item.posterUrl,
      group: item.group,
    );
    ref.read(pendingVodHistoryItemProvider.notifier).state = item;
    ref.read(iptvStreamingServiceProvider).playChannel(syntheticChannel);
    widget.onItemSelected?.call();
  }
}
