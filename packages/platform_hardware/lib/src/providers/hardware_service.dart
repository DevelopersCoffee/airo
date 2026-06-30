import 'package:platform_hardware/src/detectors/hardware_detector.dart';
import 'package:platform_hardware/src/platform/hardware_profile.dart';

abstract interface class HardwareService {
  Future<void> initialize();
  HardwareProfile get profile;
}

class DefaultHardwareService implements HardwareService {

  DefaultHardwareService(this.detector);
  final HardwareDetector detector;
  HardwareProfile? _profile;

  @override
  Future<void> initialize() async {
    _profile = await detector.detect();
  }

  @override
  HardwareProfile get profile {
    if (_profile == null) {
      throw StateError('HardwareService accessed before initialization.');
    }
    return _profile!;
  }
}
