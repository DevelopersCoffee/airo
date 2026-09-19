import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';

void main() {
  group('isAdInsertionApiUrl', () {
    test('detects IMA-only Google DAI stream-request APIs', () {
      const samples = [
        'https://dai.google.com/ondemand/v1/dash/content/123/vid/abc/stream',
        'https://dai.google.com/linear/v1/dash/event/abc/stream',
      ];

      for (final sample in samples) {
        expect(
          AiroPlaylistUrlPolicy.isAdInsertionApiUrlString(sample),
          isTrue,
          reason: sample,
        );
        expect(
          AiroPlaylistUrlPolicy.isAdInsertionApiUrl(Uri.parse(sample)),
          isTrue,
          reason: sample,
        );
      }
    });

    test('does not flag stitched DAI HLS manifests as unplayable APIs', () {
      const samples = [
        'https://dai.google.com/linear/hls/event/c-rArva4ShKVIAkNfy6HUQ/master.m3u8',
        'http://preview.dai.google.com/linear/hls/event/test/master.m3u8',
        'https://dai.google.com/linear/hls/event/test/playlist.m3u8',
      ];

      for (final sample in samples) {
        expect(
          AiroPlaylistUrlPolicy.isAdInsertionApiUrlString(sample),
          isFalse,
          reason: sample,
        );
        expect(
          AiroPlaylistUrlPolicy.playableStreamUrl(sample),
          sample,
          reason: sample,
        );
      }
    });

    test('rewrites live linear DAI stream-request URLs to HLS masters', () {
      expect(
        AiroPlaylistUrlPolicy.playableStreamUrl(
          'https://dai.google.com/linear/v1/hls/event/c-rArva4ShKVIAkNfy6HUQ/stream',
        ),
        'https://dai.google.com/linear/hls/event/c-rArva4ShKVIAkNfy6HUQ/master.m3u8',
      );
      expect(
        AiroPlaylistUrlPolicy.isAdInsertionApiUrlString(
          'https://dai.google.com/linear/v1/hls/event/c-rArva4ShKVIAkNfy6HUQ/stream',
        ),
        isFalse,
      );
    });

    test('returns null for IMA-only DAI APIs', () {
      expect(
        AiroPlaylistUrlPolicy.playableStreamUrl(
          'https://dai.google.com/ondemand/v1/dash/content/123/vid/abc/stream',
        ),
        isNull,
      );
    });

    test('does not flag ordinary HLS or lookalike hosts', () {
      const samples = [
        'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
        'https://media.example.com/live/master.m3u8',
        'https://notdai.google.com/linear/hls/event/x/master.m3u8',
        'https://dai.google.com.evil.example/master.m3u8',
        '',
        '   ',
      ];

      for (final sample in samples) {
        expect(
          AiroPlaylistUrlPolicy.isAdInsertionApiUrlString(sample),
          isFalse,
          reason: sample,
        );
      }
    });

    test('detects an unplayable DAI API embedded in an engine exception', () {
      expect(
        AiroPlaylistUrlPolicy.isAdInsertionApiUrlString(
          'PlatformException(VideoError, Failed to load '
          'https://dai.google.com/ondemand/v1/dash/content/123/vid/abc/stream, null)',
        ),
        isTrue,
      );
    });

    test('does not treat a failed DAI HLS manifest as an unplayable API', () {
      expect(
        AiroPlaylistUrlPolicy.isAdInsertionApiUrlString(
          'PlatformException(VideoError, Failed to load '
          'https://dai.google.com/linear/hls/event/x/master.m3u8, null)',
        ),
        isFalse,
      );
    });
  });

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
