import '../models/iptv_channel.dart';

/// Reusable search and filter index for channel lists.
///
/// This keeps normalized channel text and aggregate counts with the loaded
/// playlist so product UI does not rebuild them on every search keystroke.
class AiroChannelSearchIndex {
  AiroChannelSearchIndex(List<IPTVChannel> channels) {
    final categoryCounts = <ChannelCategory, int>{
      for (final category in ChannelCategory.values) category: 0,
    };
    final flavorCounts = <ChannelFlavor, int>{
      for (final flavor in ChannelFlavor.values) flavor: 0,
    };
    final channelsByFlavor = <ChannelFlavor, List<IPTVChannel>>{
      for (final flavor in ChannelFlavor.values) flavor: <IPTVChannel>[],
    };
    final entries = <_AiroChannelSearchEntry>[];

    categoryCounts[ChannelCategory.all] = channels.length;

    for (final channel in channels) {
      entries.add(_AiroChannelSearchEntry(channel));
      if (channel.category != ChannelCategory.all) {
        categoryCounts[channel.category] =
            categoryCounts[channel.category]! + 1;
      }
      flavorCounts[channel.flavor] = flavorCounts[channel.flavor]! + 1;
      channelsByFlavor[channel.flavor]!.add(channel);
    }

    _entries = List<_AiroChannelSearchEntry>.unmodifiable(entries);
    _channelsByFlavor = Map<ChannelFlavor, List<IPTVChannel>>.unmodifiable(
      channelsByFlavor.map(
        (flavor, channels) =>
            MapEntry(flavor, List<IPTVChannel>.unmodifiable(channels)),
      ),
    );
    this.categoryCounts = Map<ChannelCategory, int>.unmodifiable(
      categoryCounts,
    );
    this.flavorCounts = Map<ChannelFlavor, int>.unmodifiable(flavorCounts);
  }

  late final List<_AiroChannelSearchEntry> _entries;
  late final Map<ChannelFlavor, List<IPTVChannel>> _channelsByFlavor;
  late final Map<ChannelCategory, int> categoryCounts;
  late final Map<ChannelFlavor, int> flavorCounts;

  /// Returns a defensive snapshot without retaining another full channel list.
  List<IPTVChannel> get channels {
    return List<IPTVChannel>.unmodifiable(
      _entries.map((entry) => entry.channel),
    );
  }

  /// The index keeps search entries and flavor buckets, but no extra retained
  /// full `List<IPTVChannel>` copy beyond caller-owned provider lists.
  int get retainedFullChannelListCopies => 0;

  List<IPTVChannel> filterAndSort({
    ChannelCategory category = ChannelCategory.all,
    ChannelFlavor? flavor,
    String query = '',
    List<String> preferenceKeywords = const [],
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    final normalizedPreferences = preferenceKeywords
        .map((preference) => preference.trim().toLowerCase())
        .where((preference) => preference.isNotEmpty)
        .toList(growable: false);
    final matched = <_AiroScoredChannel>[];

    for (final entry in _entries) {
      if (category != ChannelCategory.all &&
          entry.channel.category != category) {
        continue;
      }
      if (flavor != null && entry.channel.flavor != flavor) {
        continue;
      }
      if (normalizedQuery.isNotEmpty &&
          !entry.searchText.contains(normalizedQuery)) {
        continue;
      }

      matched.add(
        _AiroScoredChannel(
          entry.channel,
          _preferenceScore(entry.searchText, normalizedPreferences),
        ),
      );
    }

    matched.sort((a, b) {
      if (a.preferenceScore != b.preferenceScore) {
        return b.preferenceScore.compareTo(a.preferenceScore);
      }
      return a.channel.name.compareTo(b.channel.name);
    });

    return List<IPTVChannel>.unmodifiable(
      matched.map((match) => match.channel),
    );
  }

  List<IPTVChannel> channelsByFlavor(ChannelFlavor flavor) {
    return _channelsByFlavor[flavor] ?? const [];
  }

  int _preferenceScore(String searchText, List<String> preferences) {
    for (var i = 0; i < preferences.length; i++) {
      if (searchText.contains(preferences[i])) {
        return preferences.length - i;
      }
    }
    return 0;
  }
}

class _AiroChannelSearchEntry {
  _AiroChannelSearchEntry(this.channel)
    : searchText = '${channel.name} ${channel.group}'.toLowerCase();

  final IPTVChannel channel;
  final String searchText;
}

class _AiroScoredChannel {
  const _AiroScoredChannel(this.channel, this.preferenceScore);

  final IPTVChannel channel;
  final int preferenceScore;
}
