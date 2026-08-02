import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'model_library_screen.dart';

/// Helps users choose a model by capability instead of model names.
class ModelAdvisorScreen extends StatefulWidget {
  const ModelAdvisorScreen({super.key, this.loadRecommendation});

  final Future<AssistantModelLibraryState> Function(AssistantTask task)?
  loadRecommendation;

  @override
  State<ModelAdvisorScreen> createState() => _ModelAdvisorScreenState();
}

class _ModelAdvisorScreenState extends State<ModelAdvisorScreen> {
  AssistantTask _task = AssistantTask.chat;
  late Future<AssistantModelLibraryState> _recommendation;

  @override
  void initState() {
    super.initState();
    _recommendation = _load(_task);
  }

  void _choose(AssistantTask task) {
    setState(() {
      _task = task;
      _recommendation = _load(task);
    });
  }

  Future<AssistantModelLibraryState> _load(AssistantTask task) {
    return widget.loadRecommendation?.call(task) ??
        AssistantModelLibraryState.load(task: task);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Model Advisor')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'What do you want to do?',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Airo compares installed and available packages against your device and recommends the best fit.',
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final task in const [
                        AssistantTask.chat,
                        AssistantTask.reasoning,
                        AssistantTask.image,
                        AssistantTask.audio,
                        AssistantTask.skills,
                        AssistantTask.actions,
                      ])
                        Semantics(
                          container: true,
                          button: true,
                          selected: _task == task,
                          label:
                              'Capability: ${_taskLabel(task)}. '
                              '${_task == task ? "Selected" : "Not selected"}.',
                          child: ExcludeSemantics(
                            child: ChoiceChip(
                              label: Text(_taskLabel(task)),
                              avatar: Icon(task.icon, size: 18),
                              selected: _task == task,
                              onSelected: (_) => _choose(task),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FutureBuilder<AssistantModelLibraryState>(
            future: _recommendation,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.error_outline),
                    title: const Text('Could not make a recommendation'),
                    subtitle: Text('${snapshot.error}'),
                  ),
                );
              }
              final state = snapshot.data;
              if (state == null) {
                return const Center(child: CircularProgressIndicator());
              }
              final candidate = state.recommended;
              return Semantics(
                container: true,
                label: _recommendationSemantics(candidate),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Recommended for ${_taskLabel(_task)}',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            candidate.local
                                ? Icons.phone_android
                                : Icons.cloud_outlined,
                          ),
                          title: Text(candidate.name),
                          subtitle: Text(candidate.description),
                          trailing: candidate.available
                              ? const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                )
                              : const Icon(Icons.info_outline),
                        ),
                        const Divider(),
                        Text(
                          'Why this choice',
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          candidate.available
                              ? '${candidate.runtime} is ready for this capability. ${candidate.privacyLabel}. ${candidate.sizeLabel}.'
                              : '${candidate.actionLabel}. ${candidate.unavailableReason ?? 'Airo will guide you through setup.'}',
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            FilledButton.icon(
                              onPressed: () =>
                                  Navigator.of(context).pop(candidate),
                              icon: const Icon(Icons.open_in_new),
                              label: Text(
                                candidate.available
                                    ? 'Use this model'
                                    : 'Open model setup',
                              ),
                            ),
                            Semantics(
                              button: true,
                              onTap: () {
                                Clipboard.setData(
                                  ClipboardData(
                                    text: _recommendationMarkdown(
                                      state: state,
                                      candidate: candidate,
                                    ),
                                  ),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Recommendation copied.'),
                                  ),
                                );
                              },
                              excludeSemantics: true,
                              label:
                                  'Copy recommendation for ${candidate.name}',
                              hint:
                                  'Copies a support-safe model advisor report for ${_taskLabel(state.task)}.',
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(
                                      text: _recommendationMarkdown(
                                        state: state,
                                        candidate: candidate,
                                      ),
                                    ),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Recommendation copied.'),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.copy),
                                label: const Text('Copy recommendation'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Copy recommendation creates a support-safe summary without file paths or logs.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  String _taskLabel(AssistantTask task) =>
      task.label.replaceAll(' Project', '');

  String _recommendationSemantics(AssistantModelCandidate candidate) {
    return 'Recommended model ${candidate.name}. '
        'Runtime ${candidate.runtime}. '
        '${candidate.privacyLabel}. '
        '${candidate.sizeLabel}. '
        '${candidate.available ? "Ready" : "Requires setup"}.';
  }

  String _recommendationMarkdown({
    required AssistantModelLibraryState state,
    required AssistantModelCandidate candidate,
  }) {
    final buffer = StringBuffer()
      ..writeln('# Airo Model Advisor Recommendation')
      ..writeln()
      ..writeln('| Field | Value |')
      ..writeln('| --- | --- |')
      ..writeln('| Capability | `${_taskLabel(state.task)}` |')
      ..writeln('| Device | `${state.deviceLabel}` |')
      ..writeln('| Platform | `${state.platformLabel}` |')
      ..writeln('| Recommended model | `${candidate.name}` |')
      ..writeln('| Runtime | `${candidate.runtime}` |')
      ..writeln(
        '| Availability | `${candidate.available ? 'ready' : 'setup_required'}` |',
      )
      ..writeln('| Privacy | `${candidate.privacyLabel}` |')
      ..writeln('| Size | `${candidate.sizeLabel}` |')
      ..writeln('| Action | `${candidate.actionLabel}` |')
      ..writeln()
      ..writeln('## Why this choice')
      ..writeln()
      ..writeln(
        candidate.available
            ? '- ${candidate.runtime} is ready for this capability.'
            : '- ${candidate.actionLabel}. ${candidate.unavailableReason ?? 'Airo will guide the setup flow.'}',
      )
      ..writeln('- ${candidate.privacyLabel}.')
      ..writeln('- ${candidate.sizeLabel}.')
      ..writeln()
      ..writeln('## Candidate tags')
      ..writeln();
    for (final tag in candidate.tags) {
      buffer.writeln('- `$tag`');
    }
    if (candidate.bestFor.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('## Best for')
        ..writeln();
      for (final task in candidate.bestFor) {
        buffer.writeln('- `${_taskLabel(task)}`');
      }
    }
    final compatibility = candidate.compatibility;
    if (compatibility != null) {
      buffer
        ..writeln()
        ..writeln('## Compatibility')
        ..writeln()
        ..writeln('- Compatible: `${compatibility.isCompatible}`')
        ..writeln('- Memory severity: `${compatibility.memorySeverity.name}`')
        ..writeln(
          '- Available memory: `${compatibility.availableMemoryMB.toStringAsFixed(0)} MB`',
        )
        ..writeln(
          '- Required memory: `${compatibility.requiredMemoryMB.toStringAsFixed(0)} MB`',
        );
      final reason = compatibility.reason;
      if (reason != null && reason.trim().isNotEmpty) {
        buffer.writeln('- Reason: $reason');
      }
    }
    if (!candidate.available && candidate.unavailableReason != null) {
      buffer
        ..writeln()
        ..writeln('## Setup reason')
        ..writeln()
        ..writeln('- ${candidate.unavailableReason}');
    }
    return buffer.toString().trimRight();
  }
}
