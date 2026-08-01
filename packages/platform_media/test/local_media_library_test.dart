import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_media/platform_media.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('io.airo.local_media.test');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('sidecar subtitles associate by basename and stay out of logs', () {
    final entries = associateLocalSidecarSubtitles(const [
      LocalMediaEntry(
        id: 'movie',
        name: 'Film.MP4',
        kind: LocalMediaEntryKind.video,
        accessUri: 'content://private/movie',
      ),
      LocalMediaEntry(
        id: 'subtitle',
        name: 'film.srt',
        kind: LocalMediaEntryKind.subtitle,
        accessUri: 'content://private/subtitle',
      ),
    ]);

    expect(entries, hasLength(1));
    expect(entries.single.subtitleUri, 'content://private/subtitle');
    expect(entries.single.toString(), isNot(contains('content://')));
    expect(entries.single.toString(), isNot(contains('Film.MP4')));
  });

  test(
    'DLNA channel adapter discovers and browses opaque network entries',
    () async {
      final methods = <String>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        methods.add(call.method);
        if (call.method == 'discoverDlna') {
          return [
            {
              'id': 'opaque-server',
              'name': 'Living room server',
              'kind': 'folder',
              'accessUri': 'dlna://server/opaque/root',
              'childrenUri': 'dlna://server/opaque/root',
            },
          ];
        }
        expect(call.arguments, {'containerUri': 'dlna://server/opaque/root'});
        return [
          {
            'id': 'opaque-movie',
            'name': 'Remote movie',
            'kind': 'video',
            'accessUri': 'http://192.168.1.2/movie.mp4',
          },
        ];
      });
      const adapter = AndroidDlnaUpnpLibraryAdapter(channel: channel);
      final devices = await adapter.discover();
      final media = await adapter.browse(devices.single.childrenUri!);

      expect(devices.single.kind, LocalMediaEntryKind.folder);
      expect(media.single.name, 'Remote movie');
      expect(media.single.accessUri, startsWith('http://'));
      expect(media.single.toString(), isNot(contains('192.168')));
      expect(methods, ['discoverDlna', 'browseDlna']);
    },
  );

  test(
    'local-media channel ids are stable and redact the opaque source id',
    () {
      final first = stableLocalMediaChannelId('private-device-object-id');
      final second = stableLocalMediaChannelId('private-device-object-id');
      final other = stableLocalMediaChannelId('another-object-id');

      expect(first, second);
      expect(first, startsWith('local-'));
      expect(first, isNot(other));
      expect(first, isNot(contains('private')));
    },
  );

  test('USB permission failure becomes a stable redacted exception', () async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(
        code: 'permission_denied',
        message: 'content://private/tree',
      );
    });
    const adapter = AndroidLocalMediaLibraryAdapter(channel: channel);

    await expectLater(
      adapter.requestRemovableStorageRoot(),
      throwsA(
        isA<LocalMediaAccessException>()
            .having((error) => error.code, 'code', 'permission_denied')
            .having(
              (error) => error.toString(),
              'redacted output',
              isNot(contains('content://')),
            ),
      ),
    );
  });

  test('channel adapter fails closed for an unknown media kind', () async {
    messenger.setMockMethodCallHandler(channel, (_) async {
      return [
        {
          'id': 'opaque-entry',
          'name': 'Unknown entry',
          'kind': 'executable',
          'accessUri': 'content://private/entry',
        },
      ];
    });
    const adapter = AndroidLocalMediaLibraryAdapter(channel: channel);

    await expectLater(
      adapter.browse('content://private/root'),
      throwsA(
        isA<FormatException>().having(
          (error) => error.toString(),
          'redacted output',
          isNot(contains('content://')),
        ),
      ),
    );
  });
}
