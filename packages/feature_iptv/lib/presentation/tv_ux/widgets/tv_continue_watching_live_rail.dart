import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_channels/platform_channels.dart';

import '../../../application/providers/iptv_providers.dart';
import '../../widgets/channel_initials.dart';
import 'tv_continue_watching_scaffold.dart';

/// Continue Watching horizontal rail for live IPTV channels (10-foot / D-pad).
class TvContinueWatchingLiveRail extends ConsumerStatefulWidget {
  const TvContinueWatchingLiveRail({
    super.key,
    required this.channels,
    required this.onPlayChannel,
    this.autofocusFirst = false,
  });

  final List<IPTVChannel> channels;
  final ValueChanged<IPTVChannel> onPlayChannel;
  final bool autofocusFirst;

  @override
  ConsumerState<TvContinueWatchingLiveRail> createState() =>
      _TvContinueWatchingLiveRailState();
}

class _TvContinueWatchingLiveRailState
    extends ConsumerState<TvContinueWatchingLiveRail> {
  var _showRemoveHint = false;

  @override
  Widget build(BuildContext context) {
    if (widget.channels.isEmpty) return const SizedBox.shrink();

    final colors = Theme.of(context).colorScheme;
    var assignedAutofocus = false;

    return TvContinueWatchingScaffold(
      showRemoveHint: _showRemoveHint,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AiroSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: AiroSpacing.md),
              child: Text(
                'Continue Watching',
                style: AiroTypography.titleLarge.copyWith(
                  color: colors.onSurface,
                ),
              ),
            ),
            SizedBox(
              height: MediaCard.railHeightFor(MediaCardVariant.continueWatching),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: widget.channels.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: AiroSpacing.md),
                itemBuilder: (context, index) {
                  final channel = widget.channels[index];
                  final autofocus = widget.autofocusFirst && !assignedAutofocus;
                  if (autofocus) assignedAutofocus = true;
                  return MediaCard(
                    key: ValueKey('cw-${channel.id}'),
                    name: channel.name,
                    subtitle: channel.group,
                    logoUrl: channel.logoUrl,
                    initials: channelInitials(channel.name),
                    variant: MediaCardVariant.continueWatching,
                    showResumeBadge: true,
                    isLive: false,
                    autofocus: autofocus,
                    selectLongPressForSecondary: true,
                    onTap: () => widget.onPlayChannel(channel),
                    onLongPress: () => _remove(channel.id),
                    onFocus: () => setState(() => _showRemoveHint = true),
                    onUnfocus: () {
                      if (!mounted) return;
                      setState(() => _showRemoveHint = false);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _remove(String channelId) async {
    await ref.read(removeFromRecentlyWatchedProvider(channelId).future);
    if (!mounted) return;
    setState(() => _showRemoveHint = false);
  }
}
