import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_player/platform_player.dart';

import 'cast_multiview_receiver_bridge.dart';
import 'iptv_providers.dart';
import 'multiview_provider.dart';

/// The receiver-side transport for whatever sender is connected, if any.
/// Defaults to [UnavailableMultiviewCastReceiverTransport] until a real
/// Cast Connect receiver exists on this platform — see
/// [AiroCastReceiverMultiviewTransport] and
/// docs/superpowers/specs/2026-09-07-cast-multiview-remote-control-spec.md's
/// Dependencies section. Override this provider the same way
/// `realCastMultiviewSenderOverride` overrides the sender-side transport.
final multiviewCastReceiverTransportProvider =
    Provider<MultiviewCastReceiverTransport>((ref) {
      return const UnavailableMultiviewCastReceiverTransport();
    });

/// Drives [multiviewProvider] from whatever transport
/// [multiviewCastReceiverTransportProvider] resolves to. Reading this
/// provider is what actually starts the bridge — see [AiroTvShell]'s
/// `ref.watch(castMultiviewReceiverBridgeProvider)`, which does so for as
/// long as the TV shell is mounted.
final castMultiviewReceiverBridgeProvider = Provider<CastMultiviewReceiverBridge>((
  ref,
) {
  final bridge = CastMultiviewReceiverBridge(
    transport: ref.watch(multiviewCastReceiverTransportProvider),
    controller: ref.watch(multiviewProvider.notifier),
    resolveChannel: (channelId) {
      final channels = ref.read(iptvChannelsProvider).value ?? const [];
      for (final channel in channels) {
        if (channel.id == channelId) return channel;
      }
      return null;
    },
  );
  bridge.start();
  ref.onDispose(() {
    // Bridge.dispose() is async (cancels stream subscriptions) but disposal
    // itself is fire-and-forget — nothing awaits a provider's onDispose.
    // ignore: discarded_futures
    bridge.dispose();
  });
  return bridge;
});
