
abstract class HardwareAccelerator {
  String get name;
}
class MetalAccelerator implements HardwareAccelerator { @override String get name => 'metal'; }
class CudaAccelerator implements HardwareAccelerator { @override String get name => 'cuda'; }
class NnapiAccelerator implements HardwareAccelerator { @override String get name => 'nnapi'; }
class CoreMlAccelerator implements HardwareAccelerator { @override String get name => 'coreml'; }
