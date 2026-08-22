import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/repositories/remote_agent_skill_store.dart';
import '../../domain/models/agent_skill.dart';
import '../../domain/services/agent_skill_registry.dart';
import '../../domain/services/remote_agent_skill_installer.dart';

/// User-facing catalogue for enabling the tools that the Airo agent may use.
class AgentSkillsScreen extends StatefulWidget {
  const AgentSkillsScreen({super.key, this.registryFuture});

  final Future<AgentSkillRegistry>? registryFuture;

  @override
  State<AgentSkillsScreen> createState() => _AgentSkillsScreenState();
}

class _AgentSkillsScreenState extends State<AgentSkillsScreen> {
  final _remoteUrlController = TextEditingController();
  bool _isInstalling = false;
  String? _installError;
  late final Future<AgentSkillRegistry> _registryFuture;

  @override
  void initState() {
    super.initState();
    _registryFuture =
        widget.registryFuture ?? AgentSkillRegistry.loadPersisted();
  }

  @override
  void dispose() {
    _remoteUrlController.dispose();
    super.dispose();
  }

  Future<void> _installRemoteSkill(AgentSkillRegistry registry) async {
    final url = _remoteUrlController.text.trim();
    if (url.isEmpty) return;
    setState(() {
      _isInstalling = true;
      _installError = null;
    });
    try {
      final preferences = await SharedPreferences.getInstance();
      final skill = await RemoteAgentSkillInstaller(
        store: RemoteAgentSkillStore(preferences),
      ).install(url);
      if (!registry.addSkill(skill)) {
        throw const FormatException(
          'A skill with this id is already installed.',
        );
      }
      _remoteUrlController.clear();
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) setState(() => _installError = error.toString());
    } finally {
      if (mounted) setState(() => _isInstalling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agent Skills')),
      body: FutureBuilder<AgentSkillRegistry>(
        future: _registryFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Could not load skills: ${snapshot.error}'),
            );
          }
          final registry = snapshot.data;
          if (registry == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final skills = registry.getAllSkills();
          final enabledCount = registry.getEnabledSkills().length;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Give Airo useful tools',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Enable only the skills you trust. Airo will show the tool action and ask for confirmation before sensitive changes.',
                      ),
                      const SizedBox(height: 12),
                      Text('$enabledCount of ${skills.length} skills enabled'),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => context.push('/assistant/chat'),
                        icon: const Icon(Icons.chat_outlined),
                        label: const Text('Try skills in AI Chat'),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Import a Google AI Edge Gallery or Airo SKILL.md',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Paste a skill folder URL or SKILL.md over HTTPS. '
                        'Text-only Gallery skills import as Assistants. '
                        'JavaScript and send-email intents are not executed. '
                        'Imported skills stay disabled until you review and enable them.',
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _remoteUrlController,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: 'Skill URL',
                          hintText:
                              'https://github.com/google-ai-edge/gallery/tree/main/skills/built-in/kitchen-adventure',
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _installRemoteSkill(registry),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          onPressed: _isInstalling
                              ? null
                              : () => _installRemoteSkill(registry),
                          icon: _isInstalling
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.download_outlined),
                          label: const Text('Import skill'),
                        ),
                      ),
                      if (_installError != null)
                        Text(
                          _installError!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              for (final skill in skills)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _AgentSkillCard(
                    skill: skill,
                    onChanged: (enabled) {
                      setState(
                        () => registry.setSkillEnabled(skill.id, enabled),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _AgentSkillCard extends StatelessWidget {
  const _AgentSkillCard({required this.skill, required this.onChanged});

  final AgentSkill skill;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    skill.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Semantics(
                  container: true,
                  label: '${skill.name} skill',
                  value: skill.enabled ? 'Enabled' : 'Disabled',
                  toggled: skill.enabled,
                  child: Switch(value: skill.enabled, onChanged: onChanged),
                ),
              ],
            ),
            Text(skill.description),
            if (skill.manifest.source != SkillSource.builtIn)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Plugin v${skill.version}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (skill.tools.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Tools: ${skill.tools.join(', ')}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
