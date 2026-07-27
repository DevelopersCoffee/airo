import 'providers/channel_filters_provider.dart';

const _canonicalIptvOrigin = 'https://developerscoffee.github.io';
const _canonicalIptvPath = '/airo/iptv';
const _deepLinkVersion = '1';
const _maxDeepLinkValueLength = 256;

/// A secret-free, host-independent intent for opening Airo TV.
class IptvDeepLinkIntent {
  const IptvDeepLinkIntent({
    required this.channelId,
    this.filters = const ChannelFilters(),
  });

  final String channelId;
  final ChannelFilters filters;

  Uri toUri({bool includeFilters = true}) {
    final query = <String, String>{'v': _deepLinkVersion, 'channel': channelId};
    if (includeFilters && filters.isActive) {
      if (filters.search.isNotEmpty) query['search'] = filters.search;
      if (filters.category case final value?) query['category'] = value;
      if (filters.country case final value?) query['country'] = value;
      if (filters.language case final value?) query['language'] = value;
    }
    return Uri.parse(
      '$_canonicalIptvOrigin$_canonicalIptvPath',
    ).replace(queryParameters: query);
  }

  static IptvDeepLinkIntent? tryParse(Uri uri) {
    final isCanonical =
        uri.scheme == 'https' &&
        uri.host == 'developerscoffee.github.io' &&
        uri.path == _canonicalIptvPath;
    final isCustomScheme =
        uri.scheme == 'airo' && (uri.host == 'iptv' || uri.path == '/iptv');
    final isInternalRoute = uri.scheme.isEmpty && uri.path == '/iptv';
    if (!isCanonical && !isCustomScheme && !isInternalRoute) return null;

    final version = uri.queryParameters['v'];
    if (version != null && version != _deepLinkVersion) return null;
    final channelId = _normalized(uri.queryParameters['channel']);
    if (channelId == null) return null;
    return IptvDeepLinkIntent(
      channelId: channelId,
      filters: ChannelFilters(
        search: _normalized(uri.queryParameters['search']) ?? '',
        category: _normalized(uri.queryParameters['category']),
        country: _normalized(uri.queryParameters['country']),
        language: _normalized(uri.queryParameters['language']),
      ),
    );
  }
}

String? _normalized(String? value) {
  final normalized = value?.trim();
  if (normalized == null ||
      normalized.isEmpty ||
      normalized.length > _maxDeepLinkValueLength) {
    return null;
  }
  return normalized;
}
