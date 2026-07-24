import 'dart:math';

import 'package:core_ui/core_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:platform_channels/platform_channels.dart';

/// Selects exclusively from the caller's already-filtered channel list.
IPTVChannel? randomFilteredChannel(
  List<IPTVChannel> channels, {
  int Function(int max)? nextInt,
}) {
  if (channels.isEmpty) return null;
  final index = (nextInt ?? Random().nextInt)(channels.length);
  return channels[index];
}

TvInputResult handleRemoteOverlayInput(
  TvInputKey key, {
  VoidCallback? onChannelPrevious,
  VoidCallback? onChannelNext,
}) {
  switch (key) {
    case TvInputKey.channelUp:
      onChannelNext?.call();
      return TvInputResult.handled;
    case TvInputKey.channelDown:
      onChannelPrevious?.call();
      return TvInputResult.handled;
    default:
      return TvInputResult.notHandled;
  }
}
