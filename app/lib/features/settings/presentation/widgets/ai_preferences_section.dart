import 'package:core_ai/core_ai.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ai/ai_router_service.dart';
import '../../application/ai_model_management.dart';
import '../../application/ai_preferences_settings.dart';
import '../../application/ai_storage_dashboard.dart';
import '../screens/ai_models_screen.dart';
import '../screens/intelligent_model_manager_screen.dart';

/// AI model preferences, rendered inside the assistant profile screen through
/// `AssistantHostAdapter.aiPreferencesSection`.
///
/// Lives in the host because the settings model, its storage dashboard, and
/// the model-manager screens it links to are all app-owned.
class AIPreferencesSection extends ConsumerWidget {
  const AIPreferencesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(aiPreferencesSettingsProvider);
    final selectedModel = ref.watch(selectedModelProvider);
    final storageDashboard = ref.watch(aiStorageDashboardProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AI Model Preferences',
          style: theme.textTheme.titleMedium?.copyWith(inherit: false),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.smart_toy_outlined),
                title: const Text('Active Model'),
                subtitle: Text(
                  selectedModel?.name ?? 'Browse or download a local model',
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const AIModelsScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings_suggest_outlined),
                title: const Text('Intelligent Model Manager'),
                subtitle: const Text('Advanced model management UI'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          const IntelligentModelManagerScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.alt_route_outlined),
                title: const Text('Routing Strategy'),
                subtitle: Text(
                  _routingStrategyLabel(settings.routingStrategy),
                  key: const Key('ai-routing-strategy-subtitle'),
                ),
                trailing: DropdownButtonHideUnderline(
                  child: DropdownButton<AIRoutingStrategy>(
                    key: const Key('ai-routing-strategy-dropdown'),
                    value: settings.routingStrategy,
                    items: AIRoutingStrategy.values.map((strategy) {
                      return DropdownMenuItem(
                        value: strategy,
                        child: Text(_routingStrategyLabel(strategy)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      ref
                          .read(aiPreferencesSettingsProvider.notifier)
                          .update(settings.copyWith(routingStrategy: value));
                    },
                  ),
                ),
              ),
              SwitchListTile(
                key: const Key('ai-auto-fallback-switch'),
                secondary: const Icon(Icons.swap_horiz_outlined),
                title: const Text('Enable Auto-Fallback'),
                subtitle: const Text(
                  'Automatically use the backup runtime when the preferred one is unavailable.',
                ),
                value: settings.autoFallback,
                onChanged: (value) {
                  ref
                      .read(aiPreferencesSettingsProvider.notifier)
                      .update(settings.copyWith(autoFallback: value));
                },
              ),
              ListTile(
                leading: const Icon(Icons.low_priority_outlined),
                title: const Text('Fallback Order'),
                subtitle: Text(_fallbackOrderLabel(settings.routingStrategy)),
              ),
              ExpansionTile(
                leading: const Icon(Icons.speed_outlined),
                title: const Text('Performance'),
                subtitle: Text(
                  '${settings.accelerationPreference.label} • '
                  '${settings.threadCount} threads • '
                  '${settings.contextLength} tokens',
                ),
                children: [
                  _SettingDropdownRow<AIAccelerationPreference>(
                    label: 'GPU Acceleration',
                    value: settings.accelerationPreference,
                    items: AIAccelerationPreference.values,
                    itemLabel: (value) => value.label,
                    onChanged: (value) {
                      ref
                          .read(aiPreferencesSettingsProvider.notifier)
                          .update(
                            settings.copyWith(accelerationPreference: value),
                          );
                    },
                  ),
                  _SettingDropdownRow<int>(
                    label: 'Thread Count',
                    value: settings.threadCount,
                    items: const [1, 2, 4, 6, 8],
                    itemLabel: (value) => '$value',
                    onChanged: (value) {
                      ref
                          .read(aiPreferencesSettingsProvider.notifier)
                          .update(settings.copyWith(threadCount: value));
                    },
                  ),
                  _SettingDropdownRow<int>(
                    label: 'Context Length',
                    value: settings.contextLength,
                    items: const [1024, 2048, 4096, 8192],
                    itemLabel: (value) => '$value tokens',
                    onChanged: (value) {
                      ref
                          .read(aiPreferencesSettingsProvider.notifier)
                          .update(settings.copyWith(contextLength: value));
                    },
                  ),
                ],
              ),
              ExpansionTile(
                leading: const Icon(Icons.storage_outlined),
                title: const Text('Storage'),
                subtitle: Text(
                  storageDashboard.when(
                    data: (summary) =>
                        '${_formatBytes(summary.totalUsedBytes)} used',
                    loading: () => 'Checking storage usage',
                    error: (_, _) => 'Storage usage unavailable',
                  ),
                ),
                children: [
                  ...storageDashboard.maybeWhen(
                    data: (summary) => summary.categories.map(
                      (category) => ListTile(
                        dense: true,
                        title: Text(category.label),
                        trailing: Text(
                          category.available
                              ? _formatBytes(category.bytes)
                              : 'Unavailable',
                        ),
                      ),
                    ),
                    orElse: () => const <Widget>[],
                  ),
                  _SettingDropdownRow<AIDownloadLocationPreference>(
                    label: 'Download Location',
                    value: settings.downloadLocation,
                    items: AIDownloadLocationPreference.values,
                    itemLabel: (value) => value.label,
                    onChanged: (value) {
                      ref
                          .read(aiPreferencesSettingsProvider.notifier)
                          .update(settings.copyWith(downloadLocation: value));
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      settings.downloadLocation ==
                              AIDownloadLocationPreference.appManaged
                          ? 'Uses app-scoped external storage when available; existing internal models remain discoverable.'
                          : 'Uses the app documents directory for private model storage.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        inherit: false,
                      ),
                    ),
                  ),
                  ListTile(
                    title: const Text('Clear Model Cache'),
                    subtitle: const Text(
                      'Remove orphaned partial files and refresh storage usage.',
                    ),
                    trailing: TextButton(
                      onPressed: () async {
                        final removed = await ref
                            .read(aiPreferencesSettingsProvider.notifier)
                            .clearModelCache();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                removed == 0
                                    ? 'No cached model files needed cleanup.'
                                    : 'Cleared $removed cached model file(s).',
                              ),
                            ),
                          );
                        }
                      },
                      child: const Text('Clear'),
                    ),
                  ),
                ],
              ),
              ExpansionTile(
                leading: const Icon(Icons.tune_outlined),
                title: const Text('Advanced'),
                subtitle: Text(
                  '${settings.memoryBudgetPercent}% memory budget • '
                  '${settings.debugLogging ? 'Debug logging on' : 'Debug logging off'}',
                ),
                children: [
                  _SettingDropdownRow<int>(
                    label: 'Memory Budget',
                    value: settings.memoryBudgetPercent,
                    items: const [40, 50, 60, 70, 80],
                    itemLabel: (value) => '$value%',
                    onChanged: (value) {
                      ref
                          .read(aiPreferencesSettingsProvider.notifier)
                          .update(
                            settings.copyWith(memoryBudgetPercent: value),
                          );
                    },
                  ),
                  SwitchListTile(
                    key: const Key('ai-debug-logging-switch'),
                    title: const Text('Debug Logging'),
                    subtitle: const Text(
                      'Keep local runtime diagnostics available for troubleshooting.',
                    ),
                    value: settings.debugLogging,
                    onChanged: (value) {
                      ref
                          .read(aiPreferencesSettingsProvider.notifier)
                          .update(settings.copyWith(debugLogging: value));
                    },
                  ),
                ],
              ),
              ExpansionTile(
                key: const Key('ai-remote-server-section'),
                leading: const Icon(Icons.router_outlined),
                title: const Text('Remote model server'),
                subtitle: Text(
                  settings.remoteServerUrl.isEmpty
                      ? 'Optional Ollama, LM Studio, or llama.cpp endpoint'
                      : settings.remoteServerUrl,
                ),
                children: const [_RemoteServerEditor()],
              ),
              ExpansionTile(
                key: const Key('ai-safety-profile-section'),
                leading: const Icon(Icons.health_and_safety_outlined),
                title: const Text('Safety Profile'),
                subtitle: Text(
                  settings.safetyProfile.label,
                  key: const Key('ai-safety-profile-subtitle'),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'Harmful-content protection always stays enabled. This setting controls additional advisory filters.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        inherit: false,
                      ),
                    ),
                  ),
                  _SettingDropdownRow<SafetyProfile>(
                    label: 'Safety posture',
                    value: settings.safetyProfile,
                    items: SafetyProfile.values,
                    itemLabel: (value) => value.label,
                    onChanged: (value) {
                      ref
                          .read(aiPreferencesSettingsProvider.notifier)
                          .update(settings.copyWith(safetyProfile: value));
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
          child: Text(
            'Use the model manager to browse downloads, set an active local model, and inspect device-specific readiness.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              inherit: false,
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingDropdownRow<T> extends StatelessWidget {
  const _SettingDropdownRow({
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> items;
  final String Function(T value) itemLabel;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      trailing: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items.map((item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(itemLabel(item)),
            );
          }).toList(),
          onChanged: (next) {
            if (next != null) {
              onChanged(next);
            }
          },
        ),
      ),
    );
  }
}

class _RemoteServerEditor extends ConsumerStatefulWidget {
  const _RemoteServerEditor();

  @override
  ConsumerState<_RemoteServerEditor> createState() =>
      _RemoteServerEditorState();
}

class _RemoteServerEditorState extends ConsumerState<_RemoteServerEditor> {
  late final TextEditingController _urlController;
  late final TextEditingController _modelController;
  late final TextEditingController _keyController;
  bool _testing = false;
  RemoteServerDiagnostics? _lastDiagnostics;
  String? _lastDiagnosticModel;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(aiPreferencesSettingsProvider);
    _urlController = TextEditingController(text: settings.remoteServerUrl);
    _modelController = TextEditingController(text: settings.remoteServerModel);
    _keyController = TextEditingController(text: settings.remoteServerApiKey);
  }

  @override
  void dispose() {
    _urlController.dispose();
    _modelController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final settings = ref.read(aiPreferencesSettingsProvider);
    final url = _urlController.text.trim();
    final model = _modelController.text.trim();
    final apiKey = _keyController.text.trim();
    await ref
        .read(aiPreferencesSettingsProvider.notifier)
        .update(
          settings.copyWith(
            remoteServerUrl: url,
            remoteServerModel: model,
            remoteServerApiKey: apiKey,
          ),
        );
    ref
        .read(aiRouterServiceProvider)
        .configureRemoteServer(baseUrl: url, model: model, apiKey: apiKey);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          url.isEmpty || model.isEmpty
              ? 'Remote model server disabled.'
              : 'Remote model server saved.',
        ),
      ),
    );
  }

  Future<void> _testConnection() async {
    final url = _urlController.text.trim();
    final model = _modelController.text.trim();
    final apiKey = _keyController.text.trim();
    if (url.isEmpty || model.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a server URL and model id first.')),
      );
      return;
    }
    setState(() => _testing = true);
    final router = ref.read(aiRouterServiceProvider);
    router.configureRemoteServer(baseUrl: url, model: model, apiKey: apiKey);
    final diagnostics = await router.diagnoseRemoteServer();
    if (!mounted) return;
    setState(() {
      _testing = false;
      _lastDiagnostics = diagnostics;
      _lastDiagnosticModel = model;
    });
    final message = diagnostics == null
        ? 'Remote server diagnostics are unavailable.'
        : diagnostics.isReady
        ? 'Connected. ${diagnostics.modelIds.length} model(s) reported.'
        : diagnostics.message ?? 'The remote server is not ready.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        children: [
          TextField(
            key: const Key('ai-remote-server-url'),
            controller: _urlController,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Server URL',
              hintText: 'http://127.0.0.1:11434/v1',
            ),
          ),
          TextField(
            key: const Key('ai-remote-server-model'),
            controller: _modelController,
            decoration: const InputDecoration(labelText: 'Model id'),
          ),
          TextField(
            key: const Key('ai-remote-server-key'),
            controller: _keyController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'API key (optional)'),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                key: const Key('ai-remote-server-test'),
                onPressed: _testing ? null : _testConnection,
                icon: _testing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.network_check_outlined),
                label: Text(_testing ? 'Testing…' : 'Test connection'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save server'),
              ),
            ],
          ),
          if (_lastDiagnostics case final diagnostics?) ...[
            const SizedBox(height: 12),
            _RemoteServerDiagnosticsCard(
              diagnostics: diagnostics,
              modelId: _lastDiagnosticModel ?? _modelController.text.trim(),
            ),
          ],
        ],
      ),
    );
  }
}

class _RemoteServerDiagnosticsCard extends StatelessWidget {
  const _RemoteServerDiagnosticsCard({
    required this.diagnostics,
    required this.modelId,
  });

  final RemoteServerDiagnostics diagnostics;
  final String modelId;

  @override
  Widget build(BuildContext context) {
    final status = diagnostics.isReady ? 'Ready' : 'Needs attention';
    final reason = diagnostics.message ?? 'The server reported models.';
    final modelCount = diagnostics.modelIds.length;
    final action = _remoteServerRecommendation(diagnostics);
    return Semantics(
      container: true,
      label:
          'Remote server diagnostics: $status. Endpoint ${diagnostics.baseUrl}. '
          'Requested model $modelId. $reason $action',
      child: Card(
        key: const Key('ai-remote-server-diagnostics'),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    diagnostics.isReady
                        ? Icons.check_circle_outline
                        : Icons.error_outline,
                    color: diagnostics.isReady
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Remote diagnostics: $status',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text('Endpoint: ${diagnostics.baseUrl}'),
              Text('Requested model: $modelId'),
              if (diagnostics.statusCode case final statusCode?)
                Text('HTTP status: $statusCode'),
              Text('Models reported: $modelCount'),
              if (diagnostics.modelIds.isNotEmpty)
                Text('Available: ${diagnostics.modelIds.take(3).join(', ')}'),
              const SizedBox(height: 8),
              Text('Reason: $reason'),
              Text('Next step: $action'),
            ],
          ),
        ),
      ),
    );
  }
}

String _remoteServerRecommendation(RemoteServerDiagnostics diagnostics) {
  return switch (diagnostics.health) {
    RemoteServerHealth.ready =>
      'Save this server, then choose the same model id when chatting.',
    RemoteServerHealth.unauthorized =>
      'Check the API key or disable authentication on your local server.',
    RemoteServerHealth.notFound =>
      'Use the OpenAI-compatible base URL, usually ending in /v1.',
    RemoteServerHealth.invalidResponse =>
      'Check that Ollama, LM Studio, or llama.cpp is exposing a /models response.',
    RemoteServerHealth.modelMissing =>
      'Choose one of the reported model ids or load the requested model in the remote server.',
    RemoteServerHealth.unavailable =>
      'Confirm the server is running and reachable from this device.',
  };
}

String _routingStrategyLabel(AIRoutingStrategy strategy) {
  return switch (strategy) {
    AIRoutingStrategy.onDeviceOnly => 'On-device only',
    AIRoutingStrategy.cloudOnly => 'Cloud only',
    AIRoutingStrategy.onDevicePreferred => 'On-device preferred',
    AIRoutingStrategy.cloudPreferred => 'Cloud preferred',
    AIRoutingStrategy.offlinePreferred => 'Offline preferred',
    AIRoutingStrategy.specificModel => 'Specific model',
    AIRoutingStrategy.userChoice => 'User choice',
  };
}

String _fallbackOrderLabel(AIRoutingStrategy strategy) {
  return switch (strategy) {
    AIRoutingStrategy.onDeviceOnly => 'On-device only',
    AIRoutingStrategy.cloudOnly => 'Cloud only',
    AIRoutingStrategy.onDevicePreferred => 'On-device first, then cloud',
    AIRoutingStrategy.cloudPreferred => 'Cloud first, then on-device',
    AIRoutingStrategy.offlinePreferred => 'Offline runtimes first, then cloud',
    AIRoutingStrategy.specificModel => 'Specific runtime first, then backup',
    AIRoutingStrategy.userChoice => 'User-selected runtime, then fallback',
  };
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}
