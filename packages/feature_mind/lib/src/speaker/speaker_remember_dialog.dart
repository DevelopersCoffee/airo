import 'package:flutter/material.dart';

import '../mind_diarization.dart';
import 'meeting_speaker_registry.dart';

/// Dialog to enroll a speaker for cross-meeting recognition (#504).
Future<String?> showSpeakerRememberDialog({
  required BuildContext context,
  required String speakerLabel,
  MeetingSpeakerRegistry registry = MeetingSpeakerRegistry.empty,
}) async {
  final initial = mindSpeakerDisplayLabel(speakerLabel, registry: registry);
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Remember speaker'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Recognize this voice automatically in future meetings.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: 'Name',
              hintText: formatMindSpeakerLabel(speakerLabel),
            ),
            autofocus: true,
            onSubmitted: (value) => Navigator.of(context).pop(value),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: const Text('Remember'),
        ),
      ],
    ),
  );
}
