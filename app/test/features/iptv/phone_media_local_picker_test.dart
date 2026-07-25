import 'package:airo_app/features/iptv/phone_media_local_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('test/phone_media_picker');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test(
    'maps Android descriptor selection without reading file bytes',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        if (call.method == 'pickVideo') {
          return <String, Object?>{
            'token': 'lease-1',
            'filePath': '/proc/self/fd/42',
            'title': 'Feature.FILM.MKV',
            'size': 6101307309,
          };
        }
        return null;
      });

      final item = await pickAndroidPhoneLocalMediaForTv(channel: channel);

      expect(item, isNotNull);
      expect(item!.filePath, '/proc/self/fd/42');
      expect(item.title, 'Feature.FILM.MKV');
      expect(item.container, 'mkv');
      expect(calls.map((call) => call.method), ['pickVideo']);
    },
  );

  test('cancel returns null', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => null);

    expect(await pickAndroidPhoneLocalMediaForTv(channel: channel), isNull);
  });

  test('source lease releases native descriptor once', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'pickVideo') {
        return <String, Object?>{
          'token': 'lease-2',
          'filePath': '/proc/self/fd/43',
          'title': 'movie.mp4',
        };
      }
      return null;
    });
    final item = await pickAndroidPhoneLocalMediaForTv(channel: channel);

    await item!.sourceLease!.release();
    await item.sourceLease!.release();

    expect(calls.map((call) => call.method), ['pickVideo', 'release']);
    expect(calls.last.arguments, {'token': 'lease-2'});
  });

  test('malformed selection releases a supplied native token', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'pickVideo') {
        return <String, Object?>{'token': 'lease-3'};
      }
      return null;
    });

    expect(await pickAndroidPhoneLocalMediaForTv(channel: channel), isNull);
    expect(calls.map((call) => call.method), ['pickVideo', 'release']);
  });
}
