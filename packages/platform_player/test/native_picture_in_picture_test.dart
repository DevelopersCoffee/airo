import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_player/platform_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.airo.player/picture_in_picture');
  final calls = <MethodCall>[];
  String isSupportedResult = 'true';
  bool requestEnterResult = true;

  setUp(() {
    calls.clear();
    isSupportedResult = 'true';
    requestEnterResult = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'isSupported':
          return isSupportedResult == 'true';
        case 'requestEnter':
          return requestEnterResult;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    AiroNativePictureInPicture.setStateChangeHandler(null);
  });

  test('isSupported returns platform value', () async {
    expect(await AiroNativePictureInPicture.isSupported(), isTrue);
    expect(calls.single.method, 'isSupported');
  });

  test('isSupported returns false when platform impl is missing', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      throw MissingPluginException();
    });
    expect(await AiroNativePictureInPicture.isSupported(), isFalse);
  });

  test('requestEnter returns whether PiP engaged', () async {
    requestEnterResult = false;
    expect(await AiroNativePictureInPicture.requestEnter(), isFalse);
    expect(calls.single.method, 'requestEnter');
  });

  test('requestEnter returns false when platform impl is missing', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      throw MissingPluginException();
    });
    expect(await AiroNativePictureInPicture.requestEnter(), isFalse);
  });

  test('state change handler receives native callbacks', () async {
    bool? received;
    AiroNativePictureInPicture.setStateChangeHandler((isActive) {
      received = isActive;
    });
    final handler = TestDefaultBinaryMessengerBinding.instance
        .defaultBinaryMessenger
        // Simulate the platform invoking the Dart-side handler.
        ;
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          channel.name,
          channel.codec.encodeMethodCall(
            const MethodCall('pictureInPictureStateChanged', true),
          ),
          (data) {},
        );
    expect(received, isTrue);
  });
}
