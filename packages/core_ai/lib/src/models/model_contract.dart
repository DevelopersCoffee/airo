import 'package:flutter/foundation.dart';

/// Product task shape for registry entries and runtime routing.
enum ModelTask {
  textGeneration('Text generation'),
  classification('Classification'),
  embedding('Embeddings'),
  speechToText('Speech to text'),
  vision('Vision');

  const ModelTask(this.displayName);

  final String displayName;
}

/// Execution backend for a model artifact — distinct from [AIProvider] branding.
enum InferenceRuntime {
  llamaCpp('GGUF · llama.cpp'),
  onnx('ONNX Runtime'),
  litertLm('LiteRT-LM'),
  mediaPipeWeb('MediaPipe · Web'),
  whisper('Whisper'),
  geminiNano('Gemini Nano'),
  geminiCloud('Gemini Cloud');

  const InferenceRuntime(this.displayName);

  final String displayName;
}

/// Per-OS install/run eligibility for a catalog entry.
@immutable
class PlatformSupport {
  const PlatformSupport({
    this.android = false,
    this.ios = false,
    this.macos = false,
    this.windows = false,
    this.linux = false,
    this.web = false,
  });

  const PlatformSupport.allNative()
    : android = true,
      ios = true,
      macos = true,
      windows = true,
      linux = true,
      web = false;

  const PlatformSupport.androidOnly()
    : android = true,
      ios = false,
      macos = false,
      windows = false,
      linux = false,
      web = false;

  const PlatformSupport.webOnly()
    : web = true,
      android = false,
      ios = false,
      macos = false,
      windows = false,
      linux = false;

  final bool android;
  final bool ios;
  final bool macos;
  final bool windows;
  final bool linux;
  final bool web;

  bool supportsCurrentPlatform() {
    if (kIsWeb) return web;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS => ios,
      TargetPlatform.macOS => macos,
      TargetPlatform.windows => windows,
      TargetPlatform.linux => linux,
      _ => false,
    };
  }

  String? unsupportedPlatformLabel() {
    if (supportsCurrentPlatform()) return null;
    if (kIsWeb) return 'Web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'Android',
      TargetPlatform.iOS => 'iOS',
      TargetPlatform.macOS => 'macOS',
      TargetPlatform.windows => 'Windows',
      TargetPlatform.linux => 'Linux',
      _ => 'This platform',
    };
  }

  Map<String, dynamic> toJson() => {
    'android': android,
    'ios': ios,
    'macos': macos,
    'windows': windows,
    'linux': linux,
    'web': web,
  };

  factory PlatformSupport.fromJson(Map<String, dynamic> json) {
    return PlatformSupport(
      android: json['android'] as bool? ?? false,
      ios: json['ios'] as bool? ?? false,
      macos: json['macos'] as bool? ?? false,
      windows: json['windows'] as bool? ?? false,
      linux: json['linux'] as bool? ?? false,
      web: json['web'] as bool? ?? false,
    );
  }
}

/// Readiness phase for download vs runtime separation.
enum ModelReadinessPhase {
  notDownloaded,
  downloaded,
  installed,
  runtimeUnavailable,
  runtimeAvailable,
  ready,
  failed,
}

@immutable
class ModelReadinessState {
  const ModelReadinessState({
    required this.phase,
    required this.headline,
    required this.detail,
    required this.isRunnable,
    required this.canPrepare,
  });

  final ModelReadinessPhase phase;
  final String headline;
  final String detail;
  final bool isRunnable;
  final bool canPrepare;

  static const notDownloaded = ModelReadinessState(
    phase: ModelReadinessPhase.notDownloaded,
    headline: 'Not downloaded',
    detail: 'Download this package to use it on device.',
    isRunnable: false,
    canPrepare: false,
  );
}
