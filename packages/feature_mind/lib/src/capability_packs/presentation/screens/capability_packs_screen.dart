import 'package:flutter/material.dart';

import '../../../runtime/mind_runtime.dart';
import '../../../runtime/models/capability_models.dart';
import '../../../runtime/ports/capability_port.dart';
import '../../../widgets/mind_palette.dart';
import '../../../widgets/mind_presence_pip.dart';
import 'capability_detail_screen.dart';

/// Surface 06 — Capability Packs.
///
/// Installed list and detail only, bound to [CapabilityPort]. The AI
/// capability drafter (#1250) and the community marketplace (#1247, #1251)
/// are milestone 20 work; their regions render here in the designed
/// position, visibly disabled, so M20 fills them in without a redesign.
class CapabilityPacksScreen extends StatefulWidget {
  const CapabilityPacksScreen({super.key, required this.capabilities});

  final CapabilityPort capabilities;

  @override
  State<CapabilityPacksScreen> createState() => _CapabilityPacksScreenState();
}

class _CapabilityPacksScreenState extends State<CapabilityPacksScreen> {
  late Future<List<InstalledCapability>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.capabilities.installed();
  }

  void _reload() {
    setState(() {
      _future = widget.capabilities.installed();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Capability Packs'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(child: MindPresencePip(isLocal: true)),
          ),
        ],
      ),
      body: FutureBuilder<List<InstalledCapability>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              key: Key('mind.capabilities.loading'),
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return _CapabilityErrorState(
              error: snapshot.error!,
              onRetry: _reload,
            );
          }

          final installed = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (installed.isEmpty)
                const _EmptyCapabilitiesState()
              else
                for (final capability in installed) ...[
                  _CapabilityRow(
                    capability: capability,
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => CapabilityDetailScreen(
                            capability: capability,
                            port: widget.capabilities,
                            onChanged: _reload,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              const SizedBox(height: 24),
              const _DisabledRegion(
                key: Key('mind.capabilities.drafter'),
                icon: Icons.auto_awesome_outlined,
                title: 'AI Capability Drafter',
                description:
                    'Describe what you need and the AI capability drafter '
                    'turns it into a pack. Coming in a future release.',
              ),
              const SizedBox(height: 12),
              const _DisabledRegion(
                key: Key('mind.capabilities.marketplace'),
                icon: Icons.storefront_outlined,
                title: 'Community Marketplace',
                description:
                    'Browse capability packs shared through the community '
                    'marketplace. Coming in a future release.',
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CapabilityRow extends StatelessWidget {
  const _CapabilityRow({required this.capability, required this.onTap});

  final InstalledCapability capability;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      title: Text(capability.name),
      subtitle: Text(
        '${capability.version} · ${capability.itemCount} items'
        '${capability.isActive ? '' : ' · inactive'}',
      ),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

class _EmptyCapabilitiesState extends StatelessWidget {
  const _EmptyCapabilitiesState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(Icons.extension_outlined, size: 40),
          SizedBox(height: 12),
          Text('No capability packs installed yet.'),
        ],
      ),
    );
  }
}

class _CapabilityErrorState extends StatelessWidget {
  const _CapabilityErrorState({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final message = error is MindPortUnavailable
        ? (error as MindPortUnavailable).toString()
        : 'Something went wrong reading installed capability packs.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: MindPalette.alarm),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

/// A section in its designed position that is visibly not working yet.
///
/// Not hidden — the person should see what's coming — and not a functional
/// stub: the button is disabled, not a dead end that pretends to do
/// something.
class _DisabledRegion extends StatelessWidget {
  const _DisabledRegion({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      enabled: false,
      container: true,
      child: Opacity(
        opacity: 0.55,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: MindPalette.ink.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: MindPalette.ink),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(description),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(onPressed: null, child: const Text('Coming soon')),
            ],
          ),
        ),
      ),
    );
  }
}
