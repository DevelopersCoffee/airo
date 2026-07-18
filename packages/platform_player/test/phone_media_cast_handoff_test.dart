import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:platform_player/platform_player.dart';

void main() {
  late Directory tempDir;
  late File mediaFile;
  late FakeAiroCastController castController;

  const device = AiroCastDevice(id: 'tv-1', name: 'Living Room TV');

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('phone_media_handoff');
    mediaFile = File('${tempDir.path}/movie.mp4');
    await mediaFile.writeAsBytes(List<int>.filled(2048, 7));
    castController = FakeAiroCastController();
    await castController.initialize();
    await castController.startDiscovery();
    await castController.connect(device);
  });

  tearDown(() async {
    await castController.dispose();
    await tempDir.delete(recursive: true);
  });

  PhoneLocalMediaItem itemFor({
    String? filePath,
    String container = 'mp4',
    String? videoCodec = 'h264',
  }) {
    return PhoneLocalMediaItem(
      filePath: filePath ?? mediaFile.path,
      title: 'Movie Night',
      container: container,
      videoCodec: videoCodec,
      duration: const Duration(minutes: 90),
    );
  }

  PhoneMediaCastHandoff handoffFor({
    PhoneMediaReceiverCapabilities capabilities =
        PhoneMediaReceiverCapabilities.chromecastDefault,
  }) {
    return PhoneMediaCastHandoff(
      castController: castController,
      capabilities: capabilities,
      bindAddress: InternetAddress.loopbackIPv4,
    );
  }

  test('rejects unsupported containers without starting a server', () async {
    final handoff = handoffFor();
    final result = await handoff.start(itemFor(container: 'avi'));

    expect(result, isA<PhoneMediaHandoffUnsupported>());
    final unsupported = result as PhoneMediaHandoffUnsupported;
    expect(unsupported.reason, PhoneMediaUnsupportedReason.container);
    expect(handoff.isServing, isFalse);
    expect(castController.currentSessionState.media, isNull);
  });

  test('rejects unsupported video codecs without starting a server', () async {
    final handoff = handoffFor();
    final result = await handoff.start(itemFor(videoCodec: 'mpeg2'));

    expect(result, isA<PhoneMediaHandoffUnsupported>());
    final unsupported = result as PhoneMediaHandoffUnsupported;
    expect(unsupported.reason, PhoneMediaUnsupportedReason.videoCodec);
    expect(handoff.isServing, isFalse);
  });

  test(
    'custom receiver capabilities can allow additional containers',
    () async {
      final handoff = handoffFor(
        capabilities: const PhoneMediaReceiverCapabilities(
          supportedContainers: {'mkv'},
          supportedVideoCodecs: {'hevc'},
        ),
      );
      final result = await handoff.start(
        itemFor(container: 'mkv', videoCodec: 'hevc'),
      );

      expect(result, isA<PhoneMediaHandoffStarted>());
      await handoff.stopHandoff();
    },
  );

  test('starts the LAN server and loads a buffered cast request', () async {
    final handoff = handoffFor();
    final result = await handoff.start(itemFor());

    expect(result, isA<PhoneMediaHandoffStarted>());
    final started = result as PhoneMediaHandoffStarted;
    expect(started.request.url.scheme, 'http');
    expect(started.request.url.path, endsWith('/media'));
    expect(started.request.contentType, 'video/mp4');
    expect(started.request.streamKind, AiroCastMediaStreamKind.buffered);
    expect(started.request.duration, const Duration(minutes: 90));
    expect(started.request.title, 'Movie Night');
    expect(handoff.isServing, isTrue);

    final loaded = castController.currentSessionState.media;
    expect(loaded, isNotNull);
    expect(loaded!.url, started.request.url);

    await handoff.stopHandoff();
  });

  test('stopHandoff stops the server and the cast session', () async {
    final handoff = handoffFor();
    await handoff.start(itemFor());
    expect(handoff.isServing, isTrue);

    await handoff.stopHandoff();
    expect(handoff.isServing, isFalse);
    expect(
      castController.currentSessionState.phase,
      isNot(AiroCastSessionPhase.playing),
    );
  });

  test('server stops when the cast session ends remotely', () async {
    final handoff = handoffFor();
    await handoff.start(itemFor());
    expect(handoff.isServing, isTrue);

    await castController.stop();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(handoff.isServing, isFalse);
  });

  test('a failed cast load tears the server down', () async {
    final throwingController = _LoadThrowingController(castController);
    final handoff = PhoneMediaCastHandoff(
      castController: throwingController,
      bindAddress: InternetAddress.loopbackIPv4,
    );

    final result = await handoff.start(itemFor());
    expect(result, isA<PhoneMediaHandoffFailed>());
    expect(handoff.isServing, isFalse);
  });

  test('server stops when the receiver disconnects', () async {
    final handoff = handoffFor();
    await handoff.start(itemFor());
    expect(handoff.isServing, isTrue);

    await castController.disconnect();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(handoff.isServing, isFalse);
  });
}

/// Delegates to the fake for state but fails every media load.
class _LoadThrowingController implements AiroCastController {
  _LoadThrowingController(this._inner);

  final FakeAiroCastController _inner;

  @override
  Future<void> load(AiroCastMediaRequest request) async {
    throw StateError('receiver rejected the media');
  }

  @override
  Stream<AiroCastDiscoveryState> get discoveryStateStream =>
      _inner.discoveryStateStream;

  @override
  Stream<AiroCastSessionSnapshot> get sessionStateStream =>
      _inner.sessionStateStream;

  @override
  AiroCastDiscoveryState get currentDiscoveryState =>
      _inner.currentDiscoveryState;

  @override
  AiroCastSessionSnapshot get currentSessionState => _inner.currentSessionState;

  @override
  Future<void> initialize() => _inner.initialize();

  @override
  Future<void> startDiscovery() => _inner.startDiscovery();

  @override
  Future<void> stopDiscovery() => _inner.stopDiscovery();

  @override
  Future<void> connect(AiroCastDevice device) => _inner.connect(device);

  @override
  Future<void> play() => _inner.play();

  @override
  Future<void> pause() => _inner.pause();

  @override
  Future<void> stop() => _inner.stop();

  @override
  Future<void> setVolume(double volume) => _inner.setVolume(volume);

  @override
  Future<void> disconnect() => _inner.disconnect();

  @override
  Future<void> dispose() async {}
}
