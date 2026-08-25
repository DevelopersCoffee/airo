import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/processing_profile_preference.dart';
import '../domain/processing_profile.dart';

/// Settings control for final-transcript processing quality.
class ProcessingProfileSettingsTile extends ConsumerWidget {
  const ProcessingProfileSettingsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(processingProfileProvider);

    return ListTile(
      key: const Key('processing_profile_settings_tile'),
      title: const Text('Final transcript quality'),
      subtitle: Text(
        '${profile.label} — ${profile.subtitle}. '
        'Live preview always stays fast.',
      ),
      trailing: DropdownButton<ProcessingProfile>(
        key: const Key('processing_profile_settings_dropdown'),
        value: profile,
        onChanged: (value) {
          if (value == null) return;
          ref.read(processingProfileProvider.notifier).select(value);
        },
        items: [
          for (final item in ProcessingProfile.values)
            DropdownMenuItem(value: item, child: Text(item.label)),
        ],
      ),
    );
  }
}
