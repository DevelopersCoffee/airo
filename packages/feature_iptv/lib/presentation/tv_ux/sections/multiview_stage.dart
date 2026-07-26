import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_player/platform_player.dart';

import '../../../application/providers/multiview_provider.dart';

class MultiviewStage extends StatelessWidget {
  const MultiviewStage({
    super.key,
    required this.sessions,
    required this.featuredChannelId,
    required this.onPromote,
    this.onSwap,
  });

  final List<IptvMultiviewSession> sessions;
  final String? featuredChannelId;
  final ValueChanged<String> onPromote;
  final void Function(String firstId, String secondId)? onSwap;

  @override
  Widget build(BuildContext context) {
    // Materialize the covariant input as the interface type. Callers may pass
    // a List<SessionSubtype>, whose runtime `firstWhere` otherwise expects an
    // `orElse` returning that subtype.
    final activeSessions = List<IptvMultiviewSession>.of(sessions);
    if (activeSessions.isEmpty) return const SizedBox.shrink();
    if (activeSessions.length == 1) {
      return _SessionSurface(
        key: const ValueKey('multiview-layout-single'),
        session: activeSessions.single,
        featured: true,
      );
    }
    if (activeSessions.length == 2) {
      return Row(
        key: const ValueKey('multiview-layout-split'),
        children: [
          for (final session in activeSessions)
            Expanded(
              child: _PromotableSurface(
                session: session,
                featured: session.id == featuredChannelId,
                onPromote: onPromote,
                onSwap: onSwap,
                featuredChannelId: featuredChannelId,
              ),
            ),
        ],
      );
    }

    return GridView.count(
      key: ValueKey('multiview-layout-quad-${activeSessions.length}'),
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 16 / 9,
      children: [
        for (final session in activeSessions)
          _PromotableSurface(
            session: session,
            featured: session.id == featuredChannelId,
            onPromote: onPromote,
            onSwap: onSwap,
            featuredChannelId: featuredChannelId,
          ),
      ],
    );
  }
}

class _PromotableSurface extends StatelessWidget {
  const _PromotableSurface({
    required this.session,
    required this.featured,
    required this.onPromote,
    required this.onSwap,
    required this.featuredChannelId,
  });

  final IptvMultiviewSession session;
  final bool featured;
  final ValueChanged<String> onPromote;
  final void Function(String firstId, String secondId)? onSwap;
  final String? featuredChannelId;

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      key: ValueKey('multiview-promote-${session.id}'),
      semanticLabel: featured
          ? '${session.channel.name}, featured'
          : '${session.channel.name}, muted tile',
      semanticHint: 'Focus for audio. Press OK to swap. Press Menu for tracks.',
      onFocus: () => onPromote(session.id),
      onSelect: featuredChannelId == null || featured || onSwap == null
          ? null
          : () => onSwap?.call(featuredChannelId!, session.id),
      onSecondaryAction: () => _showTileControls(context, session),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onPromote(session.id),
        child: _SessionSurface(session: session, featured: featured),
      ),
    );
  }
}

Future<void> _showTileControls(
  BuildContext context,
  IptvMultiviewSession session,
) {
  return showDialog<void>(
    context: context,
    builder: (context) => StreamBuilder<StreamingState>(
      stream: session.states,
      initialData: session.currentState,
      builder: (context, snapshot) {
        final state = snapshot.data ?? session.currentState;
        final audioTracks = state.tracks.where(
          (track) => track.kind == AiroPlaybackTrackKind.audio,
        );
        final subtitleTracks = state.tracks.where(
          (track) => track.kind == AiroPlaybackTrackKind.subtitle,
        );
        return SimpleDialog(
          key: ValueKey('multiview-controls-${session.id}'),
          title: Text('${session.channel.name} controls'),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 4, 24, 4),
              child: Text('Audio track'),
            ),
            for (final track in audioTracks)
              SimpleDialogOption(
                key: ValueKey('multiview-audio-${session.id}-${track.id}'),
                onPressed: () => session.selectTrack(
                  kind: AiroPlaybackTrackKind.audio,
                  trackId: track.id,
                ),
                child: Text(track.label),
              ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 12, 24, 4),
              child: Text('Subtitles'),
            ),
            SimpleDialogOption(
              key: ValueKey('multiview-subtitle-off-${session.id}'),
              onPressed: () =>
                  session.clearTrackSelection(AiroPlaybackTrackKind.subtitle),
              child: const Text('Off'),
            ),
            for (final track in subtitleTracks)
              SimpleDialogOption(
                key: ValueKey('multiview-subtitle-${session.id}-${track.id}'),
                onPressed: () => session.selectTrack(
                  kind: AiroPlaybackTrackKind.subtitle,
                  trackId: track.id,
                ),
                child: Text(track.label),
              ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 12, 24, 4),
              child: Text('Quality / bitrate'),
            ),
            for (final quality in VideoQuality.values)
              SimpleDialogOption(
                key: ValueKey(
                  'multiview-quality-${session.id}-${quality.name}',
                ),
                onPressed: () => session.setQuality(quality),
                child: Text(quality.name),
              ),
          ],
        );
      },
    ),
  );
}

class _SessionSurface extends StatelessWidget {
  const _SessionSurface({
    super.key,
    required this.session,
    required this.featured,
  });

  final IptvMultiviewSession session;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: session.states,
      initialData: session.currentState,
      builder: (context, _) {
        final player = session.buildView();
        return DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black,
            border: Border.all(
              color: featured
                  ? Theme.of(context).colorScheme.primary
                  : Colors.white24,
              width: featured ? 2 : 1,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              player ??
                  const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              Positioned(
                left: 8,
                bottom: 6,
                right: 8,
                child: Row(
                  children: [
                    Icon(
                      featured ? Icons.volume_up : Icons.volume_off,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        session.channel.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          shadows: const [
                            Shadow(color: Colors.black, blurRadius: 4),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
