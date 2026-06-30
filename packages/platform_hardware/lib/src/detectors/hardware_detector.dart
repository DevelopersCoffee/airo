// ignore_for_file: one_member_abstracts
import 'package:platform_hardware/src/platform/hardware_profile.dart';

abstract interface class HardwareDetector {
  Future<HardwareProfile> detect();
}
