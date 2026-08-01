import 'package:platform_channels/platform_channels.dart';

import 'providers/channel_filters_provider.dart';

const _canonicalIptvOrigin = 'https://developerscoffee.github.io';
const _canonicalIptvPath = '/airo/iptv';
const _referenceDeepLinkVersion = '1';
const _portableDeepLinkVersion = '2';
const _maxDeepLinkValueLength = 256;
const _maxChannelNameLength = 120;

/// A versioned intent for opening an existing or friend-shared Airo channel.
class IptvDeepLinkIntent {
  const IptvDeepLinkIntent({
    required this.channelId,
    this.filters = const ChannelFilters(),
    this.channelName,
    this.streamUrl,
  });

  final String channelId;
  final ChannelFilters filters;
  final String? channelName;
  final Uri? streamUrl;

  bool get canImport => channelName != null && streamUrl != null;

  Uri toUri({bool includeFilters = true}) {
    final query = <String, String>{
      'v': canImport ? _portableDeepLinkVersion : _referenceDeepLinkVersion,
      'channel': channelId,
    };
    if (canImport) {
      final validation = AiroPlaylistUrlPolicy.validateShareStreamUrl(
        streamUrl.toString(),
      );
      if (!validation.isAllowed) {
        throw ArgumentError.value(
          streamUrl,
          'streamUrl',
          'Only credential-free public stream URLs can be shared.',
        );
      }
      final name = _normalized(
        channelName,
        maximumLength: _maxChannelNameLength,
      );
      if (name == null) {
        throw ArgumentError.value(
          channelName,
          'channelName',
          'Enter a valid channel name.',
        );
      }
      query['name'] = name;
      query['stream'] = validation.uri.toString();
    }
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
        (uri.path == _canonicalIptvPath || uri.path == '$_canonicalIptvPath/');
    final isCustomScheme =
        uri.scheme == 'airo' && (uri.host == 'iptv' || uri.path == '/iptv');
    final isInternalRoute =
        uri.scheme.isEmpty &&
        (uri.path == '/iptv' ||
            uri.path == _canonicalIptvPath ||
            uri.path == '$_canonicalIptvPath/');
    if (!isCanonical && !isCustomScheme && !isInternalRoute) return null;

    final version = uri.queryParameters['v'] ?? _referenceDeepLinkVersion;
    if (version != _referenceDeepLinkVersion &&
        version != _portableDeepLinkVersion) {
      return null;
    }
    final channelId = _normalized(uri.queryParameters['channel']);
    if (channelId == null) return null;

    String? channelName;
    Uri? streamUrl;
    if (version == _portableDeepLinkVersion) {
      channelName = _normalized(
        uri.queryParameters['name'],
        maximumLength: _maxChannelNameLength,
      );
      final validation = AiroPlaylistUrlPolicy.validateShareStreamUrl(
        uri.queryParameters['stream'],
      );
      if (channelName == null || !validation.isAllowed) return null;
      streamUrl = validation.uri;
    }

    return IptvDeepLinkIntent(
      channelId: channelId,
      channelName: channelName,
      streamUrl: streamUrl,
      filters: ChannelFilters(
        search: _normalized(uri.queryParameters['search']) ?? '',
        category: _normalized(uri.queryParameters['category']),
        country: _normalized(uri.queryParameters['country']),
        language: _normalized(uri.queryParameters['language']),
      ),
    );
  }
}

String? _normalized(
  String? value, {
  int maximumLength = _maxDeepLinkValueLength,
}) {
  final normalized = value?.trim();
  if (normalized == null ||
      normalized.isEmpty ||
      normalized.length > maximumLength) {
    return null;
  }
  return normalized;
}
