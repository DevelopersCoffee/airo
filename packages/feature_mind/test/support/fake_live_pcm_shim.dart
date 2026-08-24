import 'package:feature_mind/src/capture/application/live_pcm_shim_port.dart';

/// Test double for [LivePcmShimPort] — no microphone.
class FakeLivePcmShim implements LivePcmShimPort {
  @override
  void Function(double normalizedRms)? onAmplitude;

  var startCalls = 0;
  var pauseCalls = 0;
  var resumeCalls = 0;
  var stopCalls = 0;
  String? lastSessionId;
  bool paused = false;

  @override
  Future<void> start({required String sessionId}) async {
    startCalls++;
    lastSessionId = sessionId;
    paused = false;
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
    paused = true;
  }

  @override
  Future<void> resume({required String sessionId}) async {
    resumeCalls++;
    lastSessionId = sessionId;
    paused = false;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    paused = false;
  }

  @override
  Future<void> dispose() async {}

  void emitAmplitude(double level) {
    onAmplitude?.call(level);
  }
}
