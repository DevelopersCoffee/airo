import 'package:core_ai/core_ai.dart';
import 'package:flutter/foundation.dart';

import 'gguf_load_outcome.dart';

/// User-facing copy for GGUF load failures — keeps assistant_runtime_service
/// free of platform-specific prose.
class GgufLoadDiagnostics {
  const GgufLoadDiagnostics._();

  static ({
    String summary,
    String detail,
    List<String> repairActions,
    String reasonCode,
  })
  describe({
    required OfflineModelInfo model,
    required GgufLoadOutcome outcome,
    required bool isMacLike,
  }) {
    final name = model.name;
    return switch (outcome.reasonCode) {
      'model_file_missing' => (
        summary: '$name is not on this device',
        detail:
            'The model file is missing from local storage. Open Models to install or repair it, then try again.',
        repairActions: const [
          'Open Models and confirm the download finished.',
          'Use Try again on the Models screen if the file failed earlier.',
          'Restart Airo Mind after the file is installed.',
        ],
        reasonCode: 'model_missing',
      ),
      'model_file_incomplete' => (
        summary: '$name download looks incomplete',
        detail: _incompleteDetail(outcome),
        repairActions: const [
          'Open Models and delete the partial download, then install again.',
          'Stay on Wi‑Fi until the full file finishes copying.',
          'Restart Airo Mind after the download completes.',
        ],
        reasonCode: 'model_incomplete',
      ),
      'init_failed' when isMacLike => _macEngineFailure(
        name,
        outcome.technicalDetail,
      ),
      _ => (
        summary: 'Could not start $name locally',
        detail: outcome.technicalDetail?.trim().isNotEmpty == true
            ? outcome.technicalDetail!.trim()
            : 'The on-device llama.cpp engine could not load this model. Try restarting the app or choosing another package.',
        repairActions: const [
          'Restart the app and try again.',
          'Open Models to repair or re-download the package.',
          'Choose another installed local model.',
        ],
        reasonCode: outcome.reasonCode ?? 'init_failed',
      ),
    };
  }

  static String _incompleteDetail(GgufLoadOutcome outcome) {
    final expected = outcome.expectedBytes;
    final found = outcome.foundBytes;
    if (expected == null || found == null) {
      return 'The file on disk does not match the expected size. Re-download the model from Models.';
    }
    return 'Expected ${_formatBytes(expected)} but found ${_formatBytes(found)} on disk. '
        'A partial copy cannot be loaded safely.';
  }

  static ({
    String summary,
    String detail,
    List<String> repairActions,
    String reasonCode,
  })
  _macEngineFailure(String name, String? technicalDetail) {
    final detail = technicalDetail?.toLowerCase() ?? '';
    if (detail.contains('overbudget') || detail.contains('over_budget')) {
      return (
        summary: 'Not enough memory for $name',
        detail:
            'This Mac does not have enough free RAM to load the local model right now. Close other apps and try again.',
        repairActions: const [
          'Quit other heavy apps, then retry from the model picker.',
          'Restart Airo Mind to release memory from Scribe processing.',
          'Pick a smaller GGUF package if one is installed.',
        ],
        reasonCode: 'memory_blocked',
      );
    }
    if (detail.contains('notinstalled') || detail.contains('not installed')) {
      return (
        summary: '$name is not installed yet',
        detail:
            'Airo Mind could not find the $name weights on disk. Open Models to install this package.',
        repairActions: const [
          'Open Models and wait for this package to finish installing.',
          'Restart Airo Mind after the model file is on disk.',
        ],
        reasonCode: 'model_missing',
      );
    }
    return (
      summary: 'Local chat is not ready yet',
      detail: technicalDetail?.trim().isNotEmpty == true
          ? 'We could not load $name on this Mac: ${technicalDetail!.trim()}'
          : 'We could not load $name on this Mac. The file is present, but the on-device engine did not start. Try restarting the app.',
      repairActions: const [
        'Restart Airo Mind, then pick this model again.',
        'Open Models and confirm this package shows as installed.',
        'If Scribe is processing a meeting, wait for it to finish and retry.',
      ],
      reasonCode: 'init_failed',
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
    }
    return '$bytes B';
  }
}
