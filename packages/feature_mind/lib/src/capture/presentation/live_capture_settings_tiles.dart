import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/live_capture_preferences.dart';
import '../domain/live_intelligence_mode.dart';
import '../domain/live_transcription_support.dart';

/// Settings for live insights and the resource governor (desktop Preview).
class LiveCaptureSettingsTiles extends ConsumerWidget {
  const LiveCaptureSettingsTiles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!liveTranscriptionPreviewSupported()) {
      return const SizedBox.shrink();
    }

    final insightsEnabled = ref.watch(liveInsightsEnabledProvider);
    final autoExpand = ref.watch(liveInsightsAutoExpandProvider);
    final intelligence = ref.watch(liveIntelligenceModeProvider);
    final showInsightsControls =
        insightsEnabled && intelligence.collectInsights;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          key: const Key('live_insights_settings_tile'),
          title: const Text('Live insights'),
          subtitle: const Text(
            'Show decisions, actions, and topics while you record. '
            'Preview on desktop.',
          ),
          value: insightsEnabled && intelligence.collectInsights,
          onChanged: intelligence.collectInsights
              ? (value) =>
                    ref.read(liveInsightsEnabledProvider.notifier).select(value)
              : null,
        ),
        SwitchListTile(
          key: const Key('live_insights_auto_expand_settings_tile'),
          title: const Text('Expand insights by default'),
          subtitle: const Text(
            'Open the insights rail when a live recording starts.',
          ),
          value: showInsightsControls && autoExpand,
          onChanged: showInsightsControls
              ? (value) => ref
                    .read(liveInsightsAutoExpandProvider.notifier)
                    .select(value)
              : null,
        ),
        ListTile(
          key: const Key('live_intelligence_settings_tile'),
          title: const Text('Live intelligence'),
          subtitle: Text(intelligence.settingsSubtitle),
          trailing: DropdownButton<LiveIntelligenceMode>(
            key: const Key('live_intelligence_settings_dropdown'),
            value: intelligence,
            onChanged: (value) {
              if (value == null) return;
              ref.read(liveIntelligenceModeProvider.notifier).select(value);
            },
            items: [
              for (final item in LiveIntelligenceMode.values)
                DropdownMenuItem(value: item, child: Text(item.menuLabel)),
            ],
          ),
        ),
      ],
    );
  }
}
