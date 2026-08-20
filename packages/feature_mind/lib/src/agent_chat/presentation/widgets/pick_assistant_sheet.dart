import 'package:flutter/material.dart';

import '../../../runtime/models/capability_models.dart';
import '../../domain/models/agent_skill.dart';
import '../../domain/services/agent_skill_registry.dart';
import '../../domain/services/persona_session.dart';
import 'mind_safety_banner.dart';

class PickAssistantSheet extends StatelessWidget {
  const PickAssistantSheet({
    super.key,
    required this.registry,
    required this.pinnedPersonaId,
    required this.onPinnedChanged,
  });

  final AgentSkillRegistry registry;
  final String? pinnedPersonaId;
  final ValueChanged<String?> onPinnedChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grouped = <AgentPersonaFamily, List<AgentSkill>>{};
    for (final persona in registry.getPersonas()) {
      grouped.putIfAbsent(persona.family, () => []).add(persona);
    }
    final families = grouped.keys.toList()
      ..sort((a, b) => familyLabel(a).compareTo(familyLabel(b)));

    return SafeArea(
      child: ListView(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Assistants',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                key: const Key('pick_assistant_close_button'),
                tooltip: 'Close',
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                },
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          Text(
            'Switch from normal chat into a specialist that stays in role.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          RadioListTile<String?>(
            key: const Key('pick_assistant_normal'),
            value: null,
            groupValue: pinnedPersonaId,
            onChanged: (value) => _select(context, value),
            title: const Text('Normal chat'),
            subtitle: const Text('Auto skills, diet plugin, general Airo'),
          ),
          for (final family in families) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
              child: Text(
                familyLabel(family),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final persona in grouped[family]!)
              RadioListTile<String?>(
                key: Key('pick_assistant_${persona.id}'),
                value: persona.id,
                groupValue: pinnedPersonaId,
                onChanged: (value) => _select(context, value),
                title: Text(persona.name),
                subtitle: Text(persona.description),
                secondary: persona.safetyClass == CapabilitySafetyClass.general
                    ? null
                    : Icon(
                        Icons.shield_outlined,
                        color: theme.colorScheme.tertiary,
                      ),
              ),
          ],
          if (pinnedPersonaId != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: MindSafetyBanner(
                safetyClass: registry.getById(pinnedPersonaId!)?.safetyClass,
              ),
            ),
        ],
      ),
    );
  }

  void _select(BuildContext context, String? value) {
    onPinnedChanged(value);
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }
}
