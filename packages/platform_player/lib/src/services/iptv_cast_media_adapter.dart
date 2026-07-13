import 'package:platform_channels/platform_channels.dart';

import '../models/cast_models.dart';

class IptvCastMediaAdapter {
  const IptvCastMediaAdapter();

  IptvCastMediaResult toCastRequest(
    IPTVChannel channel, {
    VideoQuality selectedQuality = VideoQuality.auto,
  }) {
    if (_requiresCustomHeaders(channel.headers)) {
      return IptvCastMediaResult.unsupported(
        'This channel needs custom request headers, which Cast V1 does not proxy.',
      );
    }

    final rawUrl = channel.getStreamUrl(selectedQuality).trim();
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return IptvCastMediaResult.unsupported(
        'This channel does not have a valid network stream URL.',
      );
    }
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return IptvCastMediaResult.unsupported(
        'Only http and https IPTV streams can be cast in V1.',
      );
    }

    final contentType = _contentTypeFor(uri, channel);
    if (contentType == null) {
      return IptvCastMediaResult.unsupported(
        'This stream format is not supported by Cast V1.',
      );
    }

    final imageUrl = channel.effectiveLogoUrl == null
        ? null
        : Uri.tryParse(channel.effectiveLogoUrl!);

    return IptvCastMediaResult.castable(
      AiroCastMediaRequest(
        url: uri,
        contentType: contentType,
        title: channel.name,
        subtitle: channel.group,
        imageUrl: imageUrl?.hasScheme == true ? imageUrl : null,
        streamKind: _streamKindFor(uri),
      ),
    );
  }

  bool _requiresCustomHeaders(ChannelHeaders? headers) {
    if (headers == null) return false;
    return (headers.userAgent?.isNotEmpty ?? false) ||
        (headers.referrer?.isNotEmpty ?? false);
  }

  String? _contentTypeFor(Uri uri, IPTVChannel channel) {
    final path = uri.path.toLowerCase();
    if (path.endsWith('.m3u8')) return 'application/vnd.apple.mpegurl';
    if (path.endsWith('.mp4')) return 'video/mp4';
    if (path.endsWith('.m4v')) return 'video/mp4';
    if (path.endsWith('.mp3')) return 'audio/mpeg';
    if (path.endsWith('.aac')) return 'audio/aac';
    if (channel.isAudioOnly) return 'audio/mpeg';
    return null;
  }

  AiroCastMediaStreamKind _streamKindFor(Uri uri) {
    final path = uri.path.toLowerCase();
    return path.endsWith('.m3u8')
        ? AiroCastMediaStreamKind.live
        : AiroCastMediaStreamKind.buffered;
  }
}

class IptvCastMediaResult {
  final AiroCastMediaRequest? request;
  final AiroCastError? error;

  const IptvCastMediaResult._({this.request, this.error});

  factory IptvCastMediaResult.castable(AiroCastMediaRequest request) {
    return IptvCastMediaResult._(request: request);
  }

  factory IptvCastMediaResult.unsupported(String message) {
    return IptvCastMediaResult._(
      error: AiroCastError(
        code: AiroCastErrorCode.unsupportedStream,
        message: message,
      ),
    );
  }

  bool get isCastable => request != null;
}
