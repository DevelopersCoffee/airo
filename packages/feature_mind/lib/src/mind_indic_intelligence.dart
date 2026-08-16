import 'package:core_ai/core_ai.dart';
import 'package:core_entitlements/core_entitlements.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/model_provider.dart';
import 'whisper/api/meetings_seam.dart' show sarvamEdgeSpeechAvailable;

/// How meeting minutes generation is chosen for Indic-heavy content.
enum MindIndicGenerationMode {
  /// Whisper + Qwen unless the device and install support Sarvam-1.
  auto('auto'),

  /// Always Qwen 0.5B.
  standard('standard'),

  /// Sarvam-1 when installed; fails if missing (user explicitly asked).
  enhancedIndic('enhanced_indic');

  const MindIndicGenerationMode(this.stableId);

  final String stableId;

  static MindIndicGenerationMode fromStableId(String? id) {
    return MindIndicGenerationMode.values.firstWhere(
      (mode) => mode.stableId == id,
      orElse: () => MindIndicGenerationMode.auto,
    );
  }
}

/// Reserved for a future Sarvam Edge ASR backend — not publicly downloadable yet.
enum MindIndicSpeechMode {
  auto('auto'),
  whisper('whisper'),
  sarvamEdge('sarvam_edge');

  const MindIndicSpeechMode(this.stableId);

  final String stableId;

  static MindIndicSpeechMode fromStableId(String? id) {
    return MindIndicSpeechMode.values.firstWhere(
      (mode) => mode.stableId == id,
      orElse: () => MindIndicSpeechMode.auto,
    );
  }
}

const String _generationModeKey = 'mind_indic_generation_mode';
const String _speechModeKey = 'mind_indic_speech_mode';

/// Minimum total RAM before suggesting or defaulting to Sarvam-1 (~1.5 GB file
/// plus whisper + UI headroom on an 8 GB machine).
const int kMindIndicMinTotalRamBytes = 8 * 1024 * 1024 * 1024;

/// Minimum transient free RAM before loading the Indic generation pack.
const int kMindIndicMinAvailableRamBytes = 4 * 1024 * 1024 * 1024;

/// Reads and writes user preferences for pro Indic intelligence backends.
class MindIndicPreferences {
  MindIndicPreferences._();

  static Future<MindIndicGenerationMode> readGenerationMode() async {
    final prefs = await SharedPreferences.getInstance();
    return MindIndicGenerationMode.fromStableId(prefs.getString(_generationModeKey));
  }

  static Future<void> writeGenerationMode(MindIndicGenerationMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_generationModeKey, mode.stableId);
  }

  static Future<MindIndicSpeechMode> readSpeechMode() async {
    final prefs = await SharedPreferences.getInstance();
    return MindIndicSpeechMode.fromStableId(prefs.getString(_speechModeKey));
  }

  static Future<void> writeSpeechMode(MindIndicSpeechMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_speechModeKey, mode.stableId);
  }
}

/// Device + entitlement gate for optional Sarvam-backed backends.
class MindIndicCapability {
  const MindIndicCapability({
    required this.entitlements,
    this.memoryInfo,
  });

  final Entitlements entitlements;
  final MemoryInfo? memoryInfo;

  bool get proEnabled =>
      entitlements.isEnabled(ProFeature.mindIndicIntelligence);

  bool get isDesktopHost =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux);

  bool get meetsRamGate {
    final info = memoryInfo;
    if (info == null || !info.isAvailable) {
      // Desktop hosts without a probe still allow download; generation init
      // falls back to Qwen if Sarvam cannot load.
      return isDesktopHost;
    }
    return info.totalBytes >= kMindIndicMinTotalRamBytes &&
        info.availableBytes >= kMindIndicMinAvailableRamBytes;
  }

  /// Whether Auto mode should try Sarvam-1 before Qwen.
  bool shouldPreferIndicGeneration(MindIndicGenerationMode mode) {
    if (!proEnabled) return false;
    switch (mode) {
      case MindIndicGenerationMode.standard:
        return false;
      case MindIndicGenerationMode.enhancedIndic:
        return true;
      case MindIndicGenerationMode.auto:
        return isDesktopHost && meetsRamGate;
    }
  }

  /// Sarvam Edge ASR when public weights are installed and enabled in this build.
  bool shouldPreferIndicSpeech(MindIndicSpeechMode mode) {
    if (!proEnabled) return false;
    if (mode == MindIndicSpeechMode.whisper) return false;
    if (mode == MindIndicSpeechMode.sarvamEdge) {
      return sarvamEdgeSpeechAvailable();
    }
    if (mode == MindIndicSpeechMode.auto) {
      return sarvamEdgeSpeechAvailable();
    }
    return false;
  }

  String suggestionSummary() {
    if (!proEnabled) {
      return 'Indic intelligence packs require Airo Mind Pro.';
    }
    if (!isDesktopHost) {
      return 'Enhanced Indic generation is optimized for macOS, Windows, and Linux.';
    }
    if (!meetsRamGate) {
      return 'Enhanced Indic needs about 8 GB total RAM and 4 GB free memory.';
    }
    return 'Your device can run optional Sarvam-1 for better Hindi/Marathi minutes.';
  }
}

/// Pinned optional Indic generation model (public HF mirror).
const RequiredModel pinnedIndicGenerationModel = RequiredModel(
  fileName: 'sarvam-1-Q4_K_M.gguf',
  sizeBytes: 1547736928,
  sha256:
      '608cf36dc3f79d608a6d4f7c41c81e663bd919c44ac2d61af4029a0c2322c937',
);
