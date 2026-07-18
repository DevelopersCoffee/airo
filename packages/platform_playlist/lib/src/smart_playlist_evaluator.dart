import 'package:platform_channels/platform_channels.dart';

/// A user-defined filter (CV-017) that reduces a large provider playlist
/// down to a personal, cable-TV-like view without modifying the source
/// import. Rules are additive exclusions plus an explicit include/exclude
/// override — see [SmartPlaylistEvaluator.apply] for precedence.
class SmartPlaylistRule {
  const SmartPlaylistRule({
    this.allowedLanguages,
    this.excludeAdult = false,
    this.excludeVod = false,
    this.excludeRadio = false,
    this.explicitIncludeChannelIds = const {},
    this.explicitExcludeChannelIds = const {},
  });

  /// Null means no language filter is applied. Matches if any of a
  /// channel's [IPTVChannel.languages] is in this set.
  final Set<String>? allowedLanguages;
  final bool excludeAdult;
  final bool excludeVod;
  final bool excludeRadio;

  /// Always kept, even if the channel would otherwise be excluded.
  /// Takes precedence over [explicitExcludeChannelIds].
  final Set<String> explicitIncludeChannelIds;

  /// Always dropped, even if the channel would otherwise pass every other
  /// filter. Overridden by [explicitIncludeChannelIds].
  final Set<String> explicitExcludeChannelIds;
}

/// Evaluates a [SmartPlaylistRule] against a raw provider channel list.
///
/// M3U/Xtream/Stalker sources have no formal adult/radio/VOD flag (see
/// [M3uVodAdapter]'s note on the same limitation) so this classifies those
/// shapes the same way: by [IPTVChannel.category] where already inferred,
/// falling back to a group-title keyword match. Best-effort, not exact —
/// callers that need certainty should route through explicit include/
/// exclude channel ids instead.
class SmartPlaylistEvaluator {
  static const _adultGroupKeywords = ['adult', 'xxx', 'porn'];
  static const _radioGroupKeywords = ['radio', 'fm ', 'fm-'];
  static const _vodGroupKeywords = ['vod', 'series'];

  List<IPTVChannel> apply(SmartPlaylistRule rule, List<IPTVChannel> channels) {
    return [
      for (final channel in channels)
        if (rule.explicitIncludeChannelIds.contains(channel.id) ||
            _passesAllFilters(rule, channel))
          channel,
    ];
  }

  bool _passesAllFilters(SmartPlaylistRule rule, IPTVChannel channel) {
    if (rule.explicitExcludeChannelIds.contains(channel.id)) return false;
    if (rule.excludeAdult && _isAdultShaped(channel)) return false;
    if (rule.excludeVod && _isVodShaped(channel)) return false;
    if (rule.excludeRadio && _isRadioShaped(channel)) return false;
    if (rule.allowedLanguages != null &&
        !channel.languages.any(rule.allowedLanguages!.contains)) {
      return false;
    }
    return true;
  }

  bool _isAdultShaped(IPTVChannel channel) {
    final group = channel.group.toLowerCase();
    return _adultGroupKeywords.any(group.contains);
  }

  bool _isVodShaped(IPTVChannel channel) {
    if (channel.category == ChannelCategory.movies) return true;
    final group = channel.group.toLowerCase();
    return _vodGroupKeywords.any(group.contains);
  }

  bool _isRadioShaped(IPTVChannel channel) {
    final group = channel.group.toLowerCase();
    return _radioGroupKeywords.any(group.contains);
  }
}
