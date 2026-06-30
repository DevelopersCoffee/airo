import 'package:flutter/material.dart';

import '../../domain/models/agent_skill.dart';
import '../../domain/services/agent_skill_registry.dart';

class ManageSkillsSheet extends StatefulWidget {
  const ManageSkillsSheet({
    super.key,
    required this.registry,
    required this.onChanged,
  });

  final AgentSkillRegistry registry;
  final VoidCallback onChanged;

  @override
  State<ManageSkillsSheet> createState() => _ManageSkillsSheetState();
}

class _ManageSkillsSheetState extends State<ManageSkillsSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final skills = widget.registry.getAllSkills().where((skill) {
      final query = _query.toLowerCase();
      return skill.name.toLowerCase().contains(query) ||
          skill.description.toLowerCase().contains(query) ||
          skill.id.toLowerCase().contains(query);
    }).toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Manage Skills',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('manage_skills_close_button'),
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Text(
              'View, enable, and disable Airo agent skills',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                hintText: 'Search for a skill',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  '${widget.registry.getAllSkills().length} skills',
                  style: theme.textTheme.bodySmall,
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(widget.registry.enableAll);
                    widget.onChanged();
                  },
                  child: const Text('Enable all'),
                ),
                TextButton(
                  onPressed: () {
                    setState(widget.registry.disableAll);
                    widget.onChanged();
                  },
                  child: const Text('Disable all'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Built-in skills',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: skills.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final skill = skills[index];
                  return _SkillTile(
                    skill: skill,
                    onChanged: (enabled) {
                      setState(() {
                        widget.registry.setSkillEnabled(skill.id, enabled);
                      });
                      widget.onChanged();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkillTile extends StatelessWidget {
  const _SkillTile({required this.skill, required this.onChanged});

  final AgentSkill skill;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  skill.id,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Switch(value: skill.enabled, onChanged: onChanged),
            ],
          ),
          const SizedBox(height: 4),
          Text(skill.description, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final capability in skill.capabilities)
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(capability.label),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
