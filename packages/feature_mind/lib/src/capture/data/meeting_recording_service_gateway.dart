import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Starts/stops the Android mic-use foreground notification (#1656 AC2).
///
/// A `MethodChannel` rather than a Flutter plugin because this is one app's
/// own service, not a reusable capability — same reasoning `MainActivity.kt`
/// already applies to `com.airo.gemini_nano` and its siblings. The native
/// side is `MeetingRecordingService`
/// (`app/android/app/src/product/kotlin/io/airo/app/MeetingRecordingService.kt`),
/// registered from `MainActivity.configureFlutterEngine`.
///
/// iOS and other platforms have no equivalent foreground-service concept —
/// [NoopMeetingRecordingServiceGateway] is what they get. `record_ios` itself
/// keeps the process alive via the audio session's background mode
/// (`UIBackgroundModes: audio` in `Info.plist`), so there is nothing for this
/// gateway to start there.
abstract interface class MeetingRecordingServiceGateway {
  /// Shows the persistent "recording meeting audio" notification and starts
  /// the foreground service backing it. Must be called before (or in the
  /// same frame as) [AudioRecorderPort.start] — Android kills a background
  /// process's microphone access almost immediately without an active
  /// foreground service of type `microphone`.
  Future<void> start({
    required String notificationTitle,
    String? notificationText,
  });

  /// Stops the foreground service and dismisses the notification. Idempotent
  /// — safe to call even if [start] was never called.
  Future<void> stop();
}

class PlatformMeetingRecordingServiceGateway
    implements MeetingRecordingServiceGateway {
  const PlatformMeetingRecordingServiceGateway({MethodChannel? channel})
    : _channel = channel ?? _defaultChannel;

  static const MethodChannel _defaultChannel = MethodChannel(
    'com.airo.meeting_recording',
  );

  final MethodChannel _channel;

  @override
  Future<void> start({
    required String notificationTitle,
    String? notificationText,
  }) async {
    if (!(defaultTargetPlatform == TargetPlatform.android)) return;
    await _channel.invokeMethod<void>('start', {
      'title': notificationTitle,
      'text': notificationText,
    });
  }

  @override
  Future<void> stop() async {
    if (!(defaultTargetPlatform == TargetPlatform.android)) return;
    await _channel.invokeMethod<void>('stop');
  }
}

/// Platforms with no foreground-service concept (iOS, desktop, web, tests
/// that don't care about the service). See class doc on the interface.
class NoopMeetingRecordingServiceGateway
    implements MeetingRecordingServiceGateway {
  const NoopMeetingRecordingServiceGateway();

  @override
  Future<void> start({
    required String notificationTitle,
    String? notificationText,
  }) async {}

  @override
  Future<void> stop() async {}
}
