import 'dart:math';

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
