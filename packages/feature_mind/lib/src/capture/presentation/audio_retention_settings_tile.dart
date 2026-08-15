import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/audio_retention_preference.dart';
import '../domain/audio_retention_policy.dart';

/// Settings toggle for #1656 AC5 — "raw audio retention policy... a Settings
/// toggle, not hardcoded". Drop this into whichever screen owns Airo Mind's
/// Settings surface.
class AudioRetentionSettingsTile extends ConsumerWidget {
  const AudioRetentionSettingsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final policy = ref.watch(audioRetentionPolicyProvider);
    final keepAfter = policy == AudioRetentionPolicy.keepAfterTranscript;

    return SwitchListTile(
      title: const Text('Keep meeting recordings'),
      subtitle: Text(
        keepAfter
            ? 'Raw audio stays on this device after the transcript is ready.'
            : 'Raw audio is deleted once the transcript is saved. Transcripts '
                  'and minutes are kept either way.',
      ),
      value: keepAfter,
      onChanged: (value) {
        ref
            .read(audioRetentionPolicyProvider.notifier)
            .select(
              value
                  ? AudioRetentionPolicy.keepAfterTranscript
                  : AudioRetentionPolicy.deleteAfterTranscript,
            );
      },
    );
  }
}
