/// Derives 1-2 letter initials from a channel name for display wherever a
/// logo isn't available (rail cards, mini player art tile).
///
/// Two-or-more-word names take the first letter of the first two words
/// (e.g. "City News" -> "CN"); single-word names take its first two
/// characters (e.g. "ESPN" -> "ES"); an empty/blank name falls back to "?".
///
/// Single shared implementation for [BrowseScreen] and [IPTVMiniPlayer],
/// which both rendered their own slightly-diverging copy of this logic.
String channelInitials(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';
  final words = trimmed.split(RegExp(r'\s+'));
  if (words.length >= 2 && words[0].isNotEmpty && words[1].isNotEmpty) {
    return (words[0][0] + words[1][0]).toUpperCase();
  }
  return trimmed.substring(0, trimmed.length >= 2 ? 2 : 1).toUpperCase();
}
