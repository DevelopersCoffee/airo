import 'package:core_ai/core_ai.dart';

import '../domain/hardware_profile.dart';
import '../domain/processing_plan.dart';
import '../domain/processing_profile.dart';

/// Chooses a processing strategy from audio signals, hardware, and user intent.
///
/// Accuracy dominates for [ProcessingIntent.finalTranscript]; latency dominates
/// for [ProcessingIntent.live]. Additional hardware is spent on quality, not
/// only speed.
class AdaptiveProcessingPlanner {
  const AdaptiveProcessingPlanner();

  Future<ProcessingPlan> plan({
    required ProcessingIntent intent,
    required ProcessingProfile userProfile,
    MemoryInfo? memoryInfo,
    int? audioDurationSec,
    int? audioBytes,
    bool batteryConstrained = false,
  }) async {
    final memory =
        memoryInfo ??
        await DeviceCapabilityService().getMemoryInfo(forceRefresh: false);
    final hardware = HardwareProfile.fromMemoryInfo(
      memory,
      batteryConstrained: batteryConstrained,
    );

    final effectiveProfile = _effectiveProfile(
      intent: intent,
      requested: userProfile,
      hardware: hardware,
    );
    final budgetMb = hardware.memoryBudgetMb();
    final tierLabel = _tierLabel(intent: intent, profile: effectiveProfile);
    final summary = _summaryLine(
      intent: intent,
      profile: effectiveProfile,
      tierLabel: tierLabel,
      hardware: hardware,
    );
    final details = _detailLines(
      intent: intent,
      requested: userProfile,
      effective: effectiveProfile,
      hardware: hardware,
      budgetMb: budgetMb,
      audioDurationSec: audioDurationSec,
      audioBytes: audioBytes,
    );

    return ProcessingPlan(
      intent: intent,
      requestedProfile: userProfile,
      effectiveProfile: effectiveProfile,
      memoryBudgetMb: budgetMb,
      modelTierLabel: tierLabel,
      summaryLine: summary,
      detailLines: details,
      audioDurationSec: audioDurationSec,
      audioBytes: audioBytes,
    );
  }

  ProcessingProfile _effectiveProfile({
    required ProcessingIntent intent,
    required ProcessingProfile requested,
    required HardwareProfile hardware,
  }) {
    if (intent == ProcessingIntent.live) {
      return ProcessingProfile.fast;
    }
    if (hardware.isBatteryConstrained || hardware.isLowMemoryPressure) {
      if (requested == ProcessingProfile.maximumQuality) {
        return ProcessingProfile.balanced;
      }
      if (requested == ProcessingProfile.balanced &&
          hardware.availableRamMb > 0 &&
          hardware.availableRamMb < 1536) {
        return ProcessingProfile.fast;
      }
    }
    if (hardware.totalRamMb >= 16384 &&
        !hardware.isLowMemoryPressure &&
        requested == ProcessingProfile.balanced) {
      // Powerful device: spend headroom on quality when user asked for balanced.
      return ProcessingProfile.maximumQuality;
    }
    return requested;
  }

  String _tierLabel({
    required ProcessingIntent intent,
    required ProcessingProfile profile,
  }) {
    if (intent == ProcessingIntent.live) {
      return 'Fast (live preview)';
    }
    return switch (profile) {
      ProcessingProfile.fast => 'Fast tier',
      ProcessingProfile.balanced => 'Balanced tier',
      ProcessingProfile.maximumQuality => 'Maximum quality tier',
    };
  }

  String _summaryLine({
    required ProcessingIntent intent,
    required ProcessingProfile profile,
    required String tierLabel,
    required HardwareProfile hardware,
  }) {
    if (intent == ProcessingIntent.live) {
      return 'Live preview uses $tierLabel for responsiveness.';
    }
    final adjusted =
        hardware.isLowMemoryPressure || hardware.isBatteryConstrained;
    if (adjusted && profile != ProcessingProfile.maximumQuality) {
      return 'Final transcript: $tierLabel (adjusted for device limits).';
    }
    return 'Final transcript: $tierLabel (${profile.label}).';
  }

  List<String> _detailLines({
    required ProcessingIntent intent,
    required ProcessingProfile requested,
    required ProcessingProfile effective,
    required HardwareProfile hardware,
    required int budgetMb,
    int? audioDurationSec,
    int? audioBytes,
  }) {
    final lines = <String>[
      if (intent == ProcessingIntent.finalTranscript)
        'Live preview is provisional; this pass is the source of truth.',
      'Requested: ${requested.label}',
      if (effective != requested) 'Effective: ${effective.label}',
      if (hardware.totalRamMb > 0)
        'Device RAM: ${hardware.totalRamMb} MB total, '
            '${hardware.availableRamMb} MB available',
      'Speech memory budget: $budgetMb MB',
      if (hardware.isAppleSilicon) 'Apple Silicon — GPU offload when available',
      if (hardware.isLowMemoryPressure) 'Memory pressure — capped model tier',
      if (hardware.isBatteryConstrained) 'Low battery — capped model tier',
      if (audioDurationSec != null)
        'Recording length: ${_formatDuration(audioDurationSec)}',
      if (audioBytes != null) 'Audio size: ${_formatBytes(audioBytes)}',
    ];
    return lines;
  }

  String _formatDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
