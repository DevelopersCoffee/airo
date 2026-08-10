import 'package:flutter/material.dart';

import '../../../runtime/models/capability_models.dart';
import '../../../runtime/ports/capability_port.dart';
import '../../../widgets/mind_palette.dart';

/// Detail view for one installed capability pack.
///
/// States what it does — item count and safety class — and which port it
/// touches. Surface 06 backs onto exactly one port, `CapabilityPort`, so the
/// badge always reads "Capability"; a surface with a wider port set would
/// list all of them here.
class CapabilityDetailScreen extends StatefulWidget {
  const CapabilityDetailScreen({
    super.key,
    required this.capability,
    required this.port,
    this.onChanged,
  });

  final InstalledCapability capability;
  final CapabilityPort port;

  /// Called after a change (active toggle, remove) the caller may want to
  /// react to — the list screen uses it to reload.
  final VoidCallback? onChanged;

  @override
  State<CapabilityDetailScreen> createState() =>
      _CapabilityDetailScreenState();
}

class _CapabilityDetailScreenState extends State<CapabilityDetailScreen> {
  late InstalledCapability _capability;
  bool _isTogglingActive = false;
  String? _removeError;

  static const Map<CapabilitySafetyClass, String> _safetyLabels = {
    CapabilitySafetyClass.general: 'General',
    CapabilitySafetyClass.health: 'Health',
    CapabilitySafetyClass.financial: 'Financial',
    CapabilitySafetyClass.legal: 'Legal',
  };

  @override
  void initState() {
    super.initState();
    _capability = widget.capability;
  }

  Future<void> _toggleActive(bool active) async {
    setState(() {
      _isTogglingActive = true;
      _capability = _withActive(_capability, active);
    });
    try {
      await widget.port.setActive(_capability.id, active: active);
      widget.onChanged?.call();
    } finally {
      if (mounted) setState(() => _isTogglingActive = false);
    }
  }

  Future<void> _confirmAndRemove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Remove ${_capability.name}?'),
        content: const Text(
          'The pack is removed. Contexts it created are not — they stay in '
          'the vault.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove pack'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _removeError = null);
    try {
      await widget.port.remove(_capability.id);
      widget.onChanged?.call();
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        setState(() => _removeError = 'Could not remove: $error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_capability.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Chip(
                key: const Key('mind.capabilities.detail.port'),
                label: const Text('Touches: Capability'),
              ),
              const SizedBox(width: 8),
              Chip(label: Text(_safetyLabels[_capability.safetyClass]!)),
              if (_capability.isFirstParty) ...[
                const SizedBox(width: 8),
                const Chip(label: Text('First-party')),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'Version ${_capability.version}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(width: 12),
              Text(
                '${_capability.itemCount} items',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${_capability.name} manages ${_capability.itemCount} items in '
            'contexts it created, through the Capability port only.',
          ),
          if (_capability.requiresConsentFor.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: MindPalette.alarm),
              ),
              child: Text(
                'Requires consent for: '
                '${_capability.requiresConsentFor.join(', ')}',
                style: const TextStyle(color: MindPalette.alarm),
              ),
            ),
          ],
          const SizedBox(height: 24),
          SwitchListTile(
            title: const Text('Active'),
            subtitle: Text(
              _capability.isActive
                  ? 'This pack can act on your contexts.'
                  : 'Installed, not acting.',
            ),
            value: _capability.isActive,
            onChanged: _isTogglingActive ? null : _toggleActive,
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _confirmAndRemove,
            child: const Text('Remove'),
          ),
          if (_removeError != null) ...[
            const SizedBox(height: 8),
            Text(
              _removeError!,
              style: const TextStyle(color: MindPalette.alarm),
            ),
          ],
        ],
      ),
    );
  }

  static InstalledCapability _withActive(
    InstalledCapability capability,
    bool active,
  ) {
    return InstalledCapability(
      id: capability.id,
      name: capability.name,
      version: capability.version,
      isFirstParty: capability.isFirstParty,
      isActive: active,
      itemCount: capability.itemCount,
      safetyClass: capability.safetyClass,
      requiresConsentFor: capability.requiresConsentFor,
    );
  }
}
