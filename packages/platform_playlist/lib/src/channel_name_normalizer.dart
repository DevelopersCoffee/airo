/// Normalizes a raw provider channel name for cross-provider matching
/// (CV-017). Strips cosmetic quality/mirror suffixes that don't change a
/// channel's identity (HD, FHD, 4K, Backup, ...), while deliberately
/// *keeping* regional markers (East, West, US, UK, ...) -- those represent
/// materially different feeds and must never collapse into the same
/// normalized name.
class ChannelNameNormalizer {
  static const _qualitySuffixes = {
    'hd',
    'fhd',
    'uhd',
    'sd',
    '4k',
    'hevc',
    'h265',
    'backup',
    'backup1',
    'backup2',
    'raw',
  };

  String normalize(String rawName) {
    final tokens = rawName
        .toLowerCase()
        .replaceAll(RegExp(r'[()\[\]|]'), ' ')
        .split(RegExp(r'[\s\-_.]+'))
        .where((token) => token.isNotEmpty)
        .where((token) => !_qualitySuffixes.contains(token));
    return tokens.join(' ').trim();
  }
}
