import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../compatibility/compatibility_evaluator.dart';
import '../detectors/mock_hardware_detector.dart';
import '../platform/hardware_profile.dart';
import '../providers/hardware_service.dart';

final hardwareDetectorProvider = Provider((ref) => MockHardwareDetector());

final hardwareServiceProvider = Provider<HardwareService>((ref) {
  final detector = ref.watch(hardwareDetectorProvider);
  return DefaultHardwareService(detector);
});

final hardwareProfileProvider = Provider<HardwareProfile>((ref) {
  final service = ref.watch(hardwareServiceProvider);
  return service.profile;
});

final compatibilityEvaluatorProvider = Provider<CompatibilityEvaluator>((ref) {
  return DefaultCompatibilityEvaluator();
});
