import 'dart:io';

import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const tv = AiroCastDevice(id: 'tv-1', name: 'Fire Stick');

  late Directory tempDir;
  late File mediaFile;
  late FakeAiroCastController castController;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('play_on_tv_widget');
    mediaFile = File('${tempDir.path}/movie.mp4');
    await mediaFile.writeAsBytes(List<int>.filled(1024, 3));
    castController = FakeAiroCastController(devices: const [tv]);
    await castController.initialize();
    await castController.startDiscovery();
    await castController.connect(tv);
  });

  tearDown(() async {
    await castController.dispose();
    await tempDir.delete(recursive: true);
  });

  PhoneLocalMediaItem itemFor({String container = 'mp4'}) {
    return PhoneLocalMediaItem(
      filePath: mediaFile.path,
      title: 'Movie Night',
      container: container,
      videoCodec: 'h264',
      duration: const Duration(minutes: 90),
    );
  }

  Widget hostFor(
    PhoneLocalMediaItem item, {
    FakeAiroCastController? controller,
  }) {
    final selectedController = controller ?? castController;
    return MaterialApp(
      home: Scaffold(
        body: PhoneMediaPlayOnTvSheet(
          item: item,
          handoff: PhoneMediaCastHandoff(
            castController: selectedController,
            bindAddress: InternetAddress.loopbackIPv4,
            debugConnectivityStream: const Stream.empty(),
          ),
          castController: selectedController,
        ),
      ),
    );
  }

  testWidgets('offers Play on TV naming the connected receiver', (
    tester,
  ) async {
    await tester.pumpWidget(hostFor(itemFor()));

    expect(find.text('Play on Fire Stick'), findsOneWidget);
    expect(find.textContaining('Fire Stick'), findsNWidgets(2));
    expect(find.textContaining('Movie Night'), findsOneWidget);
  });

  testWidgets('successful handoff shows Playing on receiver with stop action', (
    tester,
  ) async {
    await tester.pumpWidget(hostFor(itemFor()));

    await tester.tap(find.text('Play on Fire Stick'));
    await tester.pumpAndSettle();

    expect(find.text('Playing on Fire Stick'), findsOneWidget);
    expect(find.text('Open remote'), findsOneWidget);
    expect(find.text('Stop casting'), findsOneWidget);
  });

  testWidgets('unsupported container shows format-not-supported state', (
    tester,
  ) async {
    await tester.pumpWidget(hostFor(itemFor(container: 'avi')));

    await tester.tap(find.text('Play on Fire Stick'));
    await tester.pumpAndSettle();

    expect(find.text("This format isn't supported by your TV"), findsOneWidget);
    expect(find.text('Playing on Fire Stick'), findsNothing);
  });

  testWidgets('failed handoff shows an error state and offers retry', (
    tester,
  ) async {
    final missingFile = PhoneLocalMediaItem(
      filePath: '${tempDir.path}/does_not_exist.mp4',
      title: 'Movie Night',
      container: 'mp4',
      videoCodec: 'h264',
    );
    await tester.pumpWidget(hostFor(missingFile));

    await tester.tap(find.text('Play on Fire Stick'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't play on your TV"), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('stop casting returns to the idle offer state', (tester) async {
    await tester.pumpWidget(hostFor(itemFor()));

    await tester.tap(find.text('Play on Fire Stick'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stop casting'));
    await tester.pumpAndSettle();

    expect(find.text('Play on Fire Stick'), findsOneWidget);
    expect(find.text('Playing on Fire Stick'), findsNothing);
  });

  testWidgets('discovers a receiver and connects before starting playback', (
    tester,
  ) async {
    await castController.disconnect();
    await tester.pumpWidget(hostFor(itemFor()));
    await tester.pumpAndSettle();

    expect(find.text('Fire Stick'), findsOneWidget);
    expect(
      find.textContaining('Choose a Chromecast-enabled TV'),
      findsOneWidget,
    );

    await tester.tap(find.text('Fire Stick'));
    await tester.pumpAndSettle();

    expect(find.text('Playing on Fire Stick'), findsOneWidget);
    final connectIndex = castController.recordedActions.indexOf('connect:tv-1');
    final loadIndex = castController.recordedActions.indexWhere(
      (action) => action.startsWith('load:'),
    );
    expect(connectIndex, greaterThanOrEqualTo(0));
    expect(loadIndex, greaterThan(connectIndex));
  });

  testWidgets('shows a retryable empty state when no receivers are found', (
    tester,
  ) async {
    final emptyController = FakeAiroCastController();
    addTearDown(emptyController.dispose);

    await tester.pumpWidget(hostFor(itemFor(), controller: emptyController));
    await tester.pumpAndSettle();

    expect(find.text('No Cast devices found'), findsOneWidget);
    expect(find.text('Scan again'), findsOneWidget);
    expect(
      emptyController.recordedActions,
      isNot(contains(startsWith('load:'))),
    );
  });

  testWidgets('connection failure does not claim playback started', (
    tester,
  ) async {
    await castController.disconnect();
    castController.failConnection = true;
    await tester.pumpWidget(hostFor(itemFor()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Fire Stick'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't play on your TV"), findsOneWidget);
    expect(find.text('Find a TV'), findsOneWidget);
    expect(find.textContaining('Playing on'), findsNothing);
    expect(
      castController.recordedActions,
      isNot(contains(startsWith('load:'))),
    );
  });
}
