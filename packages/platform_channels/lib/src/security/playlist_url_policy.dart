/// Shared URL policy for user-supplied IPTV playlist data.
class AiroPlaylistUrlPolicy {
  const AiroPlaylistUrlPolicy._();

  /// Normalize a playlist-derived media stream URL.
  ///
  /// HTTP and HTTPS streams are valid IPTV sources, but local/private hosts are
  /// blocked by default so hostile playlist content cannot reach internal
  /// network services through players or cast proxies.
  static Uri? normalizeStreamUrl(
    String? value, {
    bool allowHttp = true,
    bool allowPrivateHosts = false,
  }) {
    return _normalizeNetworkUrl(
      value,
      allowHttp: allowHttp,
      allowPrivateHosts: allowPrivateHosts,
    );
  }

  /// Normalize a playlist-derived artwork/logo URL.
  static Uri? normalizeLogoUrl(
    String? value, {
    bool allowHttp = true,
    bool allowPrivateHosts = false,
  }) {
    return _normalizeNetworkUrl(
      value,
      allowHttp: allowHttp,
      allowPrivateHosts: allowPrivateHosts,
    );
  }

  /// Validate a target URL before a local relay fetches it.
  static bool isAllowedCastProxyTarget(
    Uri uri, {
    bool allowHttp = true,
    bool allowPrivateHosts = false,
  }) {
    return _isAllowedNetworkUri(
      uri,
      allowHttp: allowHttp,
      allowPrivateHosts: allowPrivateHosts,
    );
  }

  /// Returns true for localhost, link-local, RFC1918, and other non-public
  /// address ranges that must not be fetched from playlist-derived data unless
  /// the caller has an explicit user opt-in.
  static bool isPrivateOrLocalHost(String host) {
    final normalized = host.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    if (normalized == 'localhost' || normalized.endsWith('.localhost')) {
      return true;
    }
    if (normalized.endsWith('.local')) return true;

    final ipv4 = _parseIpv4(normalized);
    if (ipv4 != null) {
      final first = ipv4[0];
      final second = ipv4[1];
      return first == 0 ||
          first == 10 ||
          first == 127 ||
          (first == 100 && second >= 64 && second <= 127) ||
          (first == 169 && second == 254) ||
          (first == 172 && second >= 16 && second <= 31) ||
          (first == 192 && second == 168) ||
          first >= 224;
    }

    if (normalized.contains(':')) {
      return normalized == '::' ||
          normalized == '::1' ||
          normalized == '0:0:0:0:0:0:0:1' ||
          normalized.startsWith('fe80:') ||
          normalized.startsWith('fc') ||
          normalized.startsWith('fd');
    }

    return false;
  }

  static Uri? _normalizeNetworkUrl(
    String? value, {
    required bool allowHttp,
    required bool allowPrivateHosts,
  }) {
    final raw = value?.trim();
    if (raw == null || raw.isEmpty) return null;

    final uri = Uri.tryParse(raw);
    if (uri == null ||
        !_isAllowedNetworkUri(
          uri,
          allowHttp: allowHttp,
          allowPrivateHosts: allowPrivateHosts,
        )) {
      return null;
    }
    return uri;
  }

  static bool _isAllowedNetworkUri(
    Uri uri, {
    required bool allowHttp,
    required bool allowPrivateHosts,
  }) {
    if (!uri.hasScheme || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
      return false;
    }

    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'https' && !(allowHttp && scheme == 'http')) {
      return false;
    }

    if (!allowPrivateHosts && isPrivateOrLocalHost(uri.host)) {
      return false;
    }

    return true;
  }

  static List<int>? _parseIpv4(String host) {
    final parts = host.split('.');
    if (parts.length != 4) return null;

    final octets = <int>[];
    for (final part in parts) {
      if (part.isEmpty) return null;
      final octet = int.tryParse(part);
      if (octet == null || octet < 0 || octet > 255) {
        return null;
      }
      octets.add(octet);
    }
    return octets;
  }
}
