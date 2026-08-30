import 'package:feature_mind/src/capture/data/meeting_recording_service_gateway.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.airo.meeting_recording');
  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  test('starts the service on Android', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    await const PlatformMeetingRecordingServiceGateway().start(
      notificationTitle: 'Recording meeting audio',
      notificationText: 'Tap to return',
    );

    // The permission request runs first and is allowed to fail on a host with
    // no plugin channel — what must not happen is the service being skipped
    // because of it.
    expect(calls.map((call) => call.method), ['start']);
    expect(calls.single.arguments, {
      'title': 'Recording meeting audio',
      'text': 'Tap to return',
    });
  });

  test('does nothing off Android', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

    final gateway = const PlatformMeetingRecordingServiceGateway();
    await gateway.start(notificationTitle: 'Recording meeting audio');
    await gateway.stop();

    expect(calls, isEmpty);
  });

  test('stop is idempotent and reaches the service', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;

    final gateway = const PlatformMeetingRecordingServiceGateway();
    await gateway.stop();
    await gateway.stop();

    expect(calls.map((call) => call.method), ['stop', 'stop']);
  });
}
