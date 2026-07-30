import 'package:flutter/material.dart';

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
                        ChoiceChip(
                          label: Text(task.label.replaceAll(' Project', '')),
                          avatar: Icon(task.icon, size: 18),
                          selected: _task == task,
                          onSelected: (_) => _choose(task),
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
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recommended for ${_task.label.replaceAll(' Project', '')}',
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
                      FilledButton.icon(
                        onPressed: () => Navigator.of(context).pop(candidate),
                        icon: const Icon(Icons.open_in_new),
                        label: Text(
                          candidate.available
                              ? 'Use this model'
                              : 'Open model setup',
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
