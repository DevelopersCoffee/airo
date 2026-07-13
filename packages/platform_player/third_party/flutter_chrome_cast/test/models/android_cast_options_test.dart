import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_chrome_cast/entities/cast_options.dart';
import 'package:flutter_chrome_cast/models/android/android_cast_options.dart';

void main() {
  group('GoogleCastOptionsAndroid.toMap', () {
    test('includes appId and all base GoogleCastOptions fields', () {
      final options = GoogleCastOptionsAndroid(appId: 'CC1AD845');
      final map = options.toMap();

      expect(map['appId'], 'CC1AD845');
      expect(map.containsKey('physicalVolumeButtonsWillControlDeviceVolume'),
          isTrue);
      expect(map.containsKey('suspendSessionsWhenBackgrounded'), isTrue);
      expect(map.containsKey('disableDiscoveryAutostart'), isTrue);
      expect(map.containsKey('disableAnalyticsLogging'), isTrue);
      expect(
          map.containsKey('stopReceiverApplicationWhenEndingSession'), isTrue);
      expect(
          map.containsKey('startDiscoveryAfterFirstTapOnCastButton'), isTrue);
      expect(map.containsKey('stopCastingOnAppTerminated'), isTrue);
    });

    test('respects configured base option values', () {
      final options = GoogleCastOptionsAndroid(
        appId: 'receiver-id',
        physicalVolumeButtonsWillControlDeviceVolume: false,
        disableDiscoveryAutostart: true,
        disableAnalyticsLogging: true,
        suspendSessionsWhenBackgrounded: false,
        stopReceiverApplicationWhenEndingSession: true,
        startDiscoveryAfterFirstTapOnCastButton: false,
        stopCastingOnAppTerminated: true,
      );

      expect(
        options.toMap(),
        equals({
          'physicalVolumeButtonsWillControlDeviceVolume': false,
          'disableDiscoveryAutostart': true,
          'disableAnalyticsLogging': true,
          'suspendSessionsWhenBackgrounded': false,
          'stopReceiverApplicationWhenEndingSession': true,
          'startDiscoveryAfterFirstTapOnCastButton': false,
          'stopCastingOnAppTerminated': true,
          'appId': 'receiver-id',
        }),
      );
    });

    test('is a subtype of GoogleCastOptions', () {
      expect(
        GoogleCastOptionsAndroid(appId: 'CC1AD845'),
        isA<GoogleCastOptions>(),
      );
    });
  });
}
