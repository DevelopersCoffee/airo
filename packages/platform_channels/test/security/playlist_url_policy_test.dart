import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';

void main() {
  group('validateShareStreamUrl', () {
    test('allows a public credential-free HLS stream', () {
      final result = AiroPlaylistUrlPolicy.validateShareStreamUrl(
        'https://media.example.com/live/master.m3u8',
      );

      expect(result.isAllowed, isTrue);
      expect(result.uri?.host, 'media.example.com');
      expect(result.rejection, isNull);
    });

    test('rejects credential-bearing query parameters', () {
      for (final key in [
        'token',
        'api_key',
        'X-Amz-Signature',
        'session_id',
        'Expires',
      ]) {
        final result = AiroPlaylistUrlPolicy.validateShareStreamUrl(
          'https://media.example.com/live.m3u8?$key=do-not-share',
        );

        expect(
          result.rejection,
          AiroShareStreamUrlRejection.sensitiveQuery,
          reason: key,
        );
        expect(result.uri, isNull);
      }
    });

    test('rejects local targets, userinfo, and oversized values', () {
      expect(
        AiroPlaylistUrlPolicy.validateShareStreamUrl(
          'http://192.168.1.2/live.m3u8',
        ).rejection,
        AiroShareStreamUrlRejection.unsafeTarget,
      );
      expect(
        AiroPlaylistUrlPolicy.validateShareStreamUrl(
          'https://user:pass@example.com/live.m3u8',
        ).rejection,
        AiroShareStreamUrlRejection.unsafeTarget,
      );
      expect(
        AiroPlaylistUrlPolicy.validateShareStreamUrl(
          'https://example.com/${List.filled(2100, 'x').join()}',
        ).rejection,
        AiroShareStreamUrlRejection.tooLong,
      );
    });
  });
}
