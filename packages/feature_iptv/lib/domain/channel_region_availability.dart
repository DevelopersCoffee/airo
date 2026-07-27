import 'package:platform_channels/platform_channels.dart';

enum ChannelRegionAvailability { available, unknown, likelyBlocked }

ChannelRegionAvailability classifyChannelRegion(
  IPTVChannel channel,
  String? resolvedCountry,
) {
  if (channel.streamSources.any(
    (source) => source.health == ChannelSourceHealth.restricted,
  )) {
    return ChannelRegionAvailability.likelyBlocked;
  }
  final country = channel.country?.trim().toUpperCase();
  final region = resolvedCountry?.trim().toUpperCase();
  if (country == null || country.isEmpty || region == null || region.isEmpty) {
    return ChannelRegionAvailability.unknown;
  }
  if (country == region ||
      country == 'INT' ||
      country == 'WW' ||
      country == 'GLOBAL') {
    return ChannelRegionAvailability.available;
  }
  return ChannelRegionAvailability.likelyBlocked;
}

List<IPTVChannel> sortChannelsForRegion(
  Iterable<IPTVChannel> channels,
  String? resolvedCountry,
) {
  final indexed = channels.indexed.toList(growable: false);
  indexed.sort((left, right) {
    final availability = classifyChannelRegion(
      left.$2,
      resolvedCountry,
    ).index.compareTo(classifyChannelRegion(right.$2, resolvedCountry).index);
    return availability != 0 ? availability : left.$1.compareTo(right.$1);
  });
  return indexed.map((entry) => entry.$2).toList(growable: false);
}

IPTVChannel? firstRegionAvailableChannel(
  Iterable<IPTVChannel> channels,
  String? resolvedCountry,
) {
  for (final channel in channels) {
    if (classifyChannelRegion(channel, resolvedCountry) !=
        ChannelRegionAvailability.likelyBlocked) {
      return channel;
    }
  }
  return null;
}
