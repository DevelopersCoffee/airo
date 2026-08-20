import 'package:core_entitlements/core_entitlements.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../mind_indic_intelligence.dart';
import 'indic_intelligence_preferences.dart';
import 'mind_entitlements_provider.dart';

/// Profile setting for meeting minutes generation: Auto, Standard, or Enhanced Indic.
///
/// Mirrors the generation mode chips on the Mind Models scribe panel so
/// capture settings and the model hub stay aligned. Labels stay vendor-free;
/// catalog rows supply the actual package names.
class IndicGenerationSettingsTile extends ConsumerWidget {
  const IndicGenerationSettingsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entitlements = ref.watch(mindEntitlementsProvider);
    if (!entitlements.isEnabled(ProFeature.mindIndicIntelligence)) {
      return const ListTile(
        key: Key('indic_generation_settings_tile'),
        title: Text('Meeting minutes model'),
        subtitle: Text('Indic intelligence packs require Airo Mind Pro.'),
      );
    }

    final mode = ref.watch(indicGenerationModeProvider);
    final capability = MindIndicCapability(entitlements: entitlements);
    final showEnhanced = capability.isDesktopHost;

    return ListTile(
      key: const Key('indic_generation_settings_tile'),
      title: const Text('Meeting minutes model'),
      subtitle: Text(_subtitle(mode, capability)),
      trailing: DropdownButton<MindIndicGenerationMode>(
        key: const Key('indic_generation_settings_dropdown'),
        value: mode,
        onChanged: (value) {
          if (value == null) return;
          ref.read(indicGenerationModeProvider.notifier).select(value);
        },
        items: [
          const DropdownMenuItem(
            value: MindIndicGenerationMode.auto,
            child: Text('Auto'),
          ),
          const DropdownMenuItem(
            value: MindIndicGenerationMode.standard,
            child: Text('Standard'),
          ),
          if (showEnhanced)
            const DropdownMenuItem(
              value: MindIndicGenerationMode.enhancedIndic,
              child: Text('Enhanced Indic'),
            ),
        ],
      ),
    );
  }

  static String _subtitle(
    MindIndicGenerationMode mode,
    MindIndicCapability capability,
  ) {
    if (!capability.isDesktopHost) {
      return 'Mobile uses the standard minutes pack. Enhanced Indic is desktop-only.';
    }
    return switch (mode) {
      MindIndicGenerationMode.auto =>
        'Indic pack when RAM and install allow; otherwise the standard minutes pack.',
      MindIndicGenerationMode.standard => 'Always the standard minutes pack.',
      MindIndicGenerationMode.enhancedIndic =>
        'Indic pack when installed; fails if missing.',
    };
  }
}
