import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import '../../../application/providers/multiview_provider.dart';

class MultiviewStage extends StatelessWidget {
  const MultiviewStage({
    super.key,
    required this.sessions,
    required this.featuredChannelId,
    required this.onPromote,
  });

  final List<IptvMultiviewSession> sessions;
  final String? featuredChannelId;
  final ValueChanged<String> onPromote;

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
              ),
            ),
        ],
      );
    }

    final featured = activeSessions.firstWhere(
      (session) => session.id == featuredChannelId,
      orElse: () => activeSessions.first,
    );
    final thumbnails = activeSessions
        .where((session) => session.id != featured.id)
        .toList(growable: false);
    return Column(
      key: ValueKey('multiview-layout-featured-${activeSessions.length}'),
      children: [
        Expanded(child: _SessionSurface(session: featured, featured: true)),
        SizedBox(
          height: 108,
          child: ListView.separated(
            key: const ValueKey('multiview-thumbnail-strip'),
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            itemCount: thumbnails.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final session = thumbnails[index];
              return SizedBox(
                width: 172,
                child: _PromotableSurface(
                  session: session,
                  featured: false,
                  onPromote: onPromote,
                ),
              );
            },
          ),
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
  });

  final IptvMultiviewSession session;
  final bool featured;
  final ValueChanged<String> onPromote;

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      key: ValueKey('multiview-promote-${session.id}'),
      semanticLabel: featured
          ? '${session.channel.name}, featured'
          : 'Feature ${session.channel.name}',
      onSelect: featured ? null : () => onPromote(session.id),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: featured ? null : () => onPromote(session.id),
        child: _SessionSurface(session: session, featured: featured),
      ),
    );
  }
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
