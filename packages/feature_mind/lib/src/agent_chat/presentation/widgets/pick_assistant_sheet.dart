import 'package:flutter/material.dart';

import '../../../runtime/models/capability_models.dart';
import '../../domain/models/agent_plugin_catalog.dart';
import '../../domain/models/agent_skill.dart';
import '../../domain/services/agent_plugin_catalog_loader.dart';
import '../../domain/services/agent_skill_registry.dart';
import '../../domain/services/persona_session.dart';
import '../../domain/services/plugin_version.dart';
import 'mind_safety_banner.dart';

class PickAssistantSheet extends StatefulWidget {
  const PickAssistantSheet({
    super.key,
    required this.registry,
    required this.pinnedPersonaId,
    required this.onPinnedChanged,
    this.catalog,
    this.loadCatalog,
    this.onInstall,
  });

  final AgentSkillRegistry registry;
  final String? pinnedPersonaId;
  final ValueChanged<String?> onPinnedChanged;
  final AgentPluginCatalog? catalog;
  final Future<AgentPluginCatalog> Function()? loadCatalog;
  final Future<void> Function(AgentPluginCatalogEntry entry)? onInstall;

  @override
  State<PickAssistantSheet> createState() => _PickAssistantSheetState();
}

class _PickAssistantSheetState extends State<PickAssistantSheet> {
  AgentPluginCatalog _catalog = const AgentPluginCatalog([]);
  String? _busyPluginId;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.catalog != null) {
      _catalog = widget.catalog!;
    } else {
      _loadCatalog();
    }
  }

  Future<void> _loadCatalog() async {
    try {
      final catalog =
          await (widget.loadCatalog ?? AgentPluginCatalogLoader().load)();
      if (!mounted) return;
      setState(() => _catalog = catalog);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not refresh the plugin catalog.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grouped = <AgentPersonaFamily, List<AgentSkill>>{};
    for (final persona in widget.registry.getPersonas().where(
      (persona) => persona.isEnabled,
    )) {
      grouped.putIfAbsent(persona.family, () => []).add(persona);
    }
    final families = grouped.keys.toList()
      ..sort((a, b) => familyLabel(a).compareTo(familyLabel(b)));
    final installedIds = {
      for (final persona in widget.registry.getPersonas()) persona.id,
    };
    final available = _catalog.entries
        .where((entry) => !installedIds.contains(entry.id))
        .toList(growable: false);

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
            'Switch from normal chat into a specialist that stays in role. '
            'Specialists are downloadable plugins and are versioned.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          RadioListTile<String?>(
            key: const Key('pick_assistant_normal'),
            value: null,
            groupValue: widget.pinnedPersonaId,
            onChanged: (value) => _select(value),
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
                groupValue: widget.pinnedPersonaId,
                onChanged: (value) => _select(value),
                title: Text(persona.name),
                subtitle: Text('${persona.description}\nv${persona.version}'),
                isThreeLine: true,
                secondary: _installedTrailing(theme, persona),
              ),
          ],
          if (available.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
              child: Text(
                'Available to install',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final entry in available)
              ListTile(
                key: Key('pick_assistant_install_${entry.id}'),
                title: Text(entry.name),
                subtitle: Text('${entry.description}\nv${entry.version}'),
                isThreeLine: true,
                onTap: widget.onInstall == null || _busyPluginId == entry.id
                    ? null
                    : () => _install(entry),
                trailing: _busyPluginId == entry.id
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        Icons.download_outlined,
                        color: theme.colorScheme.primary,
                      ),
              ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          if (widget.pinnedPersonaId != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: MindSafetyBanner(
                safetyClass: widget.registry
                    .getById(widget.pinnedPersonaId!)
                    ?.safetyClass,
              ),
            ),
        ],
      ),
    );
  }

  Widget? _installedTrailing(ThemeData theme, AgentSkill persona) {
    final catalogEntry = _catalog.getById(persona.id);
    final hasUpdate =
        catalogEntry != null &&
        pluginVersionIsNewer(catalogEntry.version, persona.version);
    if (hasUpdate && widget.onInstall != null) {
      return TextButton(
        key: Key('pick_assistant_update_${persona.id}'),
        onPressed: _busyPluginId == persona.id
            ? null
            : () => _install(catalogEntry),
        child: Text('Update to v${catalogEntry.version}'),
      );
    }
    if (persona.safetyClass == CapabilitySafetyClass.general) {
      return null;
    }
    return Icon(Icons.shield_outlined, color: theme.colorScheme.tertiary);
  }

  Future<void> _install(AgentPluginCatalogEntry entry) async {
    final install = widget.onInstall;
    if (install == null) return;
    setState(() {
      _busyPluginId = entry.id;
      _error = null;
    });
    try {
      await install(entry);
      if (!mounted) return;
      setState(() => _busyPluginId = null);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busyPluginId = null;
        _error =
            'Could not install ${entry.name}. Check the network and retry.';
      });
    }
  }

  void _select(String? value) {
    widget.onPinnedChanged(value);
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }
}
