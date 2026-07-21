import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_player/platform_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.airo.player/picture_in_picture');
  final calls = <MethodCall>[];
  String isSupportedResult = 'true';
  bool requestEnterResult = true;
  bool isActiveResult = false;

  setUp(() {
    calls.clear();
    isSupportedResult = 'true';
    requestEnterResult = true;
    isActiveResult = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          switch (call.method) {
            case 'isSupported':
              return isSupportedResult == 'true';
            case 'requestEnter':
              return requestEnterResult;
            case 'isActive':
              return isActiveResult;
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

  test('setAutoEnterEnabled forwards the enabled flag to the platform',
      () async {
    await AiroNativePictureInPicture.setAutoEnterEnabled(true);
    expect(calls.single.method, 'setAutoEnterEnabled');
    expect(calls.single.arguments, {'enabled': true});

    calls.clear();
    await AiroNativePictureInPicture.setAutoEnterEnabled(false);
    expect(calls.single.arguments, {'enabled': false});
  });

  test('setAutoEnterEnabled no-ops when platform impl is missing', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          throw MissingPluginException();
        });
    // Must not throw.
    await AiroNativePictureInPicture.setAutoEnterEnabled(true);
  });

  test('isActive returns platform value', () async {
    expect(await AiroNativePictureInPicture.isActive(), isFalse);
    isActiveResult = true;
    expect(await AiroNativePictureInPicture.isActive(), isTrue);
    expect(calls.map((c) => c.method), ['isActive', 'isActive']);
  });

  test('isActive returns false when platform impl is missing', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          throw MissingPluginException();
        });
    expect(await AiroNativePictureInPicture.isActive(), isFalse);
  });

  test('state change handler receives native callbacks', () async {
    bool? received;
    AiroNativePictureInPicture.setStateChangeHandler((isActive) {
      received = isActive;
    });
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
