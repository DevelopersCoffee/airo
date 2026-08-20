import 'package:flutter/foundation.dart';

import 'model_contract.dart';
import 'model_readiness_service.dart';
import 'offline_model_info.dart';

/// Compile-time switch for the standalone Mind **desktop** binary.
///
/// Set by `--dart-define=AIRO_MIND_DESKTOP=true` in `run_mind_macos.sh` and
/// the macOS verify script. Android Mind APK builds leave this unset so they
/// can still offer LiteRT / AICore.
const bool kAiroMindDesktopHost = bool.fromEnvironment('AIRO_MIND_DESKTOP');

/// Which on-device inference stack a shell is allowed to ship.
///
/// This is a framework contract, not a UI hint. Catalog registration, default
/// chat packages, and warmup adapters all key off the profile so a macOS
/// Mind binary does not advertise Android Gallery LiteRT packages.
enum ModelRuntimeProfile {
  /// Pixel / Android Gallery: LiteRT-LM, Gemini Nano, and GGUF.
  androidOnDevice,

  /// macOS / Windows / Linux: llama.cpp GGUF only.
  desktopGguf,

  /// Browser MediaPipe `.task` bundles.
  webMediaPipe;

  bool get offersLiteRt => this == androidOnDevice;

  bool get offersGeminiNano => this == androidOnDevice;

  bool get offersGguf => this == desktopGguf || this == androidOnDevice;

  /// Resolve from compile-time desktop flag and the host's Android bit.
  static ModelRuntimeProfile resolve({required bool isAndroidHost}) {
    if (kAiroMindDesktopHost) return desktopGguf;
    if (kIsWeb) return webMediaPipe;
    return isAndroidHost ? androidOnDevice : desktopGguf;
  }

  bool offersPackage(OfflineModelInfo model) {
    final runtime = model.effectiveRuntime;
    return switch (this) {
      androidOnDevice => true,
      desktopGguf =>
        runtime == InferenceRuntime.llamaCpp ||
            runtime == InferenceRuntime.whisper ||
            runtime == InferenceRuntime.onnx,
      webMediaPipe =>
        runtime == InferenceRuntime.mediaPipeWeb || model.supportsWebRuntime,
    };
  }
}
