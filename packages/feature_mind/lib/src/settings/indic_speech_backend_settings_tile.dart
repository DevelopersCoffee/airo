import 'package:core_entitlements/core_entitlements.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mind_indic_intelligence.dart';
import '../whisper/api/meetings_seam.dart' show sarvamEdgeSpeechAvailable;
import 'indic_intelligence_preferences.dart';
import 'mind_entitlements_provider.dart';

/// Speech-backend preference for meeting capture.
///
/// Unpublished ASR backends are omitted until public weights exist in this
/// build. Catalog rows on Models supply the actual package names.
class IndicSpeechBackendSettingsTile extends ConsumerWidget {
  const IndicSpeechBackendSettingsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entitlements = ref.watch(mindEntitlementsProvider);
    if (!entitlements.isEnabled(ProFeature.mindIndicIntelligence)) {
      return const SizedBox.shrink();
    }

    final mode = ref.watch(indicSpeechModeProvider);
    final extraBackendAvailable = sarvamEdgeSpeechAvailable();
    final effectiveMode =
        !extraBackendAvailable && mode == MindIndicSpeechMode.sarvamEdge
        ? MindIndicSpeechMode.auto
        : mode;

    return ListTile(
      key: const Key('indic_speech_backend_settings_tile'),
      title: const Text('Speech backend'),
      subtitle: Text(_subtitle(effectiveMode, extraBackendAvailable)),
      trailing: DropdownButton<MindIndicSpeechMode>(
        key: const Key('indic_speech_backend_settings_dropdown'),
        value: effectiveMode,
        onChanged: (value) {
          if (value == null) return;
          ref.read(indicSpeechModeProvider.notifier).select(value);
        },
        items: [
          const DropdownMenuItem(
            value: MindIndicSpeechMode.auto,
            child: Text('Auto'),
          ),
          const DropdownMenuItem(
            value: MindIndicSpeechMode.whisper,
            child: Text('On-device speech'),
          ),
          if (extraBackendAvailable)
            const DropdownMenuItem(
              value: MindIndicSpeechMode.sarvamEdge,
              child: Text('Indic speech pack'),
            ),
        ],
      ),
    );
  }

  static String _subtitle(
    MindIndicSpeechMode mode,
    bool extraBackendAvailable,
  ) {
    if (extraBackendAvailable && mode == MindIndicSpeechMode.sarvamEdge) {
      return 'Uses the installed Indic speech pack.';
    }
    return 'Uses the installed on-device speech weights.';
  }
}
