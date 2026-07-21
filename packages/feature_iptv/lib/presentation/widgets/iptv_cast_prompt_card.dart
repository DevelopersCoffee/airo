import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import "package:platform_channels/platform_channels.dart";

import '../../application/providers/iptv_cast_prompt_providers.dart';

/// CV-028 "Before connection" prompt: a prominent, sender-only, contextual
/// invitation to cast the active channel. Never shown automatically without
/// an active channel, never on the receiver UI, and never repeated within
/// the dismissal cooldown (see [iptvCastPromptCooldownProvider]).
class IptvCastPromptCard extends ConsumerWidget {
  const IptvCastPromptCard({
    required this.channel,
    required this.onChooseTv,
    super.key,
  });

  final IPTVChannel channel;
  final VoidCallback? onChooseTv;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = ref.watch(iptvCastPromptVisibleProvider);
    if (!visible) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Icon(Icons.cast, color: colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Play on TV', style: textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    'Send this channel to a Chromecast-enabled TV.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonal(
                      onPressed: onChooseTv,
                      child: const Text('Choose a TV'),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Not now',
              icon: const Icon(Icons.close),
              onPressed: () =>
                  ref.read(iptvCastPromptCooldownProvider.notifier).dismiss(),
            ),
          ],
        ),
      ),
    );
  }
}
