import 'package:core_entitlements/core_entitlements.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mind_indic_intelligence.dart';
import '../whisper/api/meetings_seam.dart' show sarvamEdgeSpeechAvailable;
import 'indic_intelligence_preferences.dart';
import 'mind_entitlements_provider.dart';

/// Reserved seam for a future on-device Indic ASR backend (Sarvam Edge).
///
/// Today every path uses Whisper; Sarvam Edge is not publicly downloadable.
class IndicSpeechBackendSettingsTile extends ConsumerWidget {
  const IndicSpeechBackendSettingsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entitlements = ref.watch(mindEntitlementsProvider);
    if (!entitlements.isEnabled(ProFeature.mindIndicIntelligence)) {
      return const SizedBox.shrink();
    }

    final mode = ref.watch(indicSpeechModeProvider);
    final capability = MindIndicCapability(entitlements: entitlements);

    return ListTile(
      key: const Key('indic_speech_backend_settings_tile'),
      title: const Text('Indic speech backend (preview)'),
      subtitle: Text(
        _subtitle(mode, capability),
      ),
      trailing: DropdownButton<MindIndicSpeechMode>(
        key: const Key('indic_speech_backend_settings_dropdown'),
        value: mode,
        onChanged: (value) {
          if (value == null) return;
          ref.read(indicSpeechModeProvider.notifier).select(value);
        },
        items: [
          const DropdownMenuItem(
            value: MindIndicSpeechMode.auto,
            child: Text('Auto (Whisper)'),
          ),
          const DropdownMenuItem(
            value: MindIndicSpeechMode.whisper,
            child: Text('Whisper only'),
          ),
          DropdownMenuItem(
            value: MindIndicSpeechMode.sarvamEdge,
            enabled: capability.shouldPreferIndicSpeech(
              MindIndicSpeechMode.sarvamEdge,
            ),
            child: Text(
              sarvamEdgeSpeechAvailable()
                  ? 'Sarvam Edge'
                  : 'Sarvam Edge (not available)',
            ),
          ),
        ],
      ),
    );
  }

  static String _subtitle(MindIndicSpeechMode mode, MindIndicCapability capability) {
    if (mode == MindIndicSpeechMode.sarvamEdge) {
      return 'Sarvam Edge is not publicly downloadable yet — Whisper stays active.';
    }
    return 'Whisper multilingual is the on-device speech engine today.';
  }
}
