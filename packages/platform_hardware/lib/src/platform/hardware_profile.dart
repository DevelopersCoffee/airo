import 'package:platform_hardware/src/capabilities/capability_descriptors.dart';
import 'package:platform_hardware/src/capabilities/detection_result.dart';

class HardwareProfile {

  const HardwareProfile({
    required this.deviceId,
    required this.manufacturer,
    required this.model,
    required this.platform,
    required this.osVersion,
    required this.architecture,
    required this.cpu,
    required this.gpu,
    required this.npu,
    required this.availableMemoryMb,
    required this.totalMemoryMb,
    required this.availableStorageMb,
    required this.supportsMetal,
    required this.supportsVulkan,
    required this.supportsOpenCL,
    required this.supportsNNAPI,
    required this.supportsCoreML,
    required this.supportsGPUInference,
    required this.supportsBackgroundExecution,
  });
  final String deviceId;
  final String manufacturer;
  final String model;
  final String platform;
  final String osVersion;
  final String architecture;

  final DetectionResult<CPUCapability> cpu;
  final DetectionResult<GPUCapability> gpu;
  final DetectionResult<NPUCapability> npu;
  
  final DetectionResult<int> availableMemoryMb;
  final DetectionResult<int> totalMemoryMb;
  final DetectionResult<int> availableStorageMb;

  final bool supportsMetal;
  final bool supportsVulkan;
  final bool supportsOpenCL;
  final bool supportsNNAPI;
  final bool supportsCoreML;
  final bool supportsGPUInference;
  final bool supportsBackgroundExecution;
}
