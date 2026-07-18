import 'package:screen_brightness/screen_brightness.dart';

/// Reads and writes screen brightness for the Netflix-style gesture control.
///
/// Scoped to *application* brightness (not system brightness): dimming the
/// player should only affect this app's window, and `screen_brightness`
/// auto-resets application brightness when the app backgrounds/exits.
abstract class PlayerBrightnessController {
  Future<double> currentBrightness();
  Future<void> setBrightness(double value);
  Future<void> resetBrightness();
}

class SystemPlayerBrightnessController implements PlayerBrightnessController {
  final _plugin = ScreenBrightness.instance;

  @override
  Future<double> currentBrightness() => _plugin.application;

  @override
  Future<void> setBrightness(double value) =>
      _plugin.setApplicationScreenBrightness(value);

  @override
  Future<void> resetBrightness() => _plugin.resetApplicationScreenBrightness();
}

class FakePlayerBrightnessController implements PlayerBrightnessController {
  FakePlayerBrightnessController({this.initial = 0.5}) : _current = initial;

  final double initial;
  double _current;

  final List<double> setBrightnessCalls = [];
  int resetCalls = 0;

  @override
  Future<double> currentBrightness() async => _current;

  @override
  Future<void> setBrightness(double value) async {
    _current = value;
    setBrightnessCalls.add(value);
  }

  @override
  Future<void> resetBrightness() async {
    _current = initial;
    resetCalls++;
  }
}
