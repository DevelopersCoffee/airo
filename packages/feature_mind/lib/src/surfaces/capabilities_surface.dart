import 'package:flutter/material.dart';

import '../runtime/mind_runtime.dart';
import '../runtime/models/capability_models.dart';
import '../widgets/mind_palette.dart';
import 'mind_surface_scaffold.dart';

/// Surface 06. The AI capability builder leads, because describing a
/// workflow is the fastest path to a domain app. Sandbox limits are printed
/// on the row itself, not buried in a permissions sheet.
///
/// The drafter and the community section render in their designed position,
/// disabled. Milestone 20 owns the AI drafter (#1250) and the marketplace
/// (#1247, #1251); this surface's job is to not need a redesign when they
/// land.
class CapabilitiesSurface extends StatefulWidget {
  const CapabilitiesSurface({super.key, required this.runtime, this.onBack});

  final MindRuntime runtime;
  final VoidCallback? onBack;

  @override
  State<CapabilitiesSurface> createState() => _CapabilitiesSurfaceState();
}

class _CapabilitiesSurfaceState extends State<CapabilitiesSurface> {
  late Future<List<InstalledCapability>> _installed;

  @override
  void initState() {
    super.initState();
    _installed = widget.runtime.capabilities.installed();
  }

  void _reload() {
    // A block body, not `() => _installed = ...`. That arrow form's value IS
    // the assignment's right-hand side -- a Future here -- and setState()
    // rejects a callback that appears to return one, assuming it was
    // mistakenly marked async.
    setState(() {
      _installed = widget.runtime.capabilities.installed();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<InstalledCapability>>(
      future: _installed,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final error = snapshot.error;
          final failure = error is MindPortUnavailable
              ? error
              : MindPortUnavailable('MindRuntime', '$error');
          return MindSurfaceScaffold(
            title: 'CAPABILITIES',
            status: MindSurfaceStatus.unavailable(failure.port, failure.reason),
            onBack: widget.onBack,
            child: const SizedBox.shrink(),
          );
        }

        final installed = snapshot.data;
        if (installed == null) {
          return const MindSurfaceScaffold(
            title: 'CAPABILITIES',
            status: MindSurfaceStatus.rebuilding(opsProcessed: 0, opsTotal: 0),
            child: SizedBox.shrink(),
          );
        }

        return MindSurfaceScaffold(
          title: 'CAPABILITIES',
          status: const MindSurfaceStatus.live(
            opCount: 0,
            peerCount: 0,
            vaultSealed: true,
          ),
          onBack: widget.onBack,
          trailing: const Icon(Icons.search, color: MindPalette.ink, size: 22),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                  children: [
                    const _DrafterCard(),
                    const SizedBox(height: 20),
                    _InstalledSection(
                      capabilities: installed,
                      onTap: (capability) => _openDetail(context, capability),
                    ),
                    const SizedBox(height: 20),
                    const _CommunitySection(),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 14, 18, 24),
                child: Text(
                  'Capabilities are declarative data, not code. A pack can '
                  'describe a workflow; it cannot reach the network.',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.2,
                    color: MindPalette.grid,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openDetail(
    BuildContext context,
    InstalledCapability capability,
  ) async {
    final removed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: MindPalette.surface,
      builder: (context) => _CapabilityDetailSheet(
        capability: capability,
        onRemove: () async {
          await widget.runtime.capabilities.remove(capability.id);
        },
      ),
    );
    if (removed == true) _reload();
  }
}

class _DrafterCard extends StatelessWidget {
  const _DrafterCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border.all(color: MindPalette.grid)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'BUILD ONE',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 2,
              color: MindPalette.remote,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '"Manage my family\'s medical records"',
            style: TextStyle(fontSize: 15, height: 1.4, color: MindPalette.ink),
          ),
          const SizedBox(height: 10),
          Text(
            'Describe a workflow and Airo drafts the schemas, views and '
            'automations for your review. Nothing installs until you '
            'approve it.',
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: MindPalette.ink.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          // Disabled: onTap is null, not a no-op closure. A no-op would let
          // the row look interactive while doing nothing, which is worse
          // than looking exactly as unfinished as it is. M20 owns turning
          // this into a real drafter (#1250).
          InkWell(
            onTap: null,
            child: Container(
              height: 48,
              alignment: Alignment.center,
              color: MindPalette.ink.withValues(alpha: 0.3),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 19,
                    color: MindPalette.onFilled,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'DRAFT A CAPABILITY',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.8,
                      color: MindPalette.onFilled,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InstalledSection extends StatelessWidget {
  const _InstalledSection({required this.capabilities, required this.onTap});

  final List<InstalledCapability> capabilities;
  final void Function(InstalledCapability capability) onTap;

  static const _icons = {
    'hospital_recovery': Icons.healing_outlined,
    'property_maintenance': Icons.home_repair_service_outlined,
    'tax_2026': Icons.receipt_long_outlined,
    'audio_scribe': Icons.graphic_eq,
    'prompt_lab': Icons.science_outlined,
  };

  /// The design's middle segment: "first-party", "consent-gated", or, for a
  /// capability with no first-party/consent signal to show, nothing. There is
  /// no port field distinguishing "developer tool" from a domain capability
  /// -- Prompt Lab's "v1.0 · developer tool" label in the design is written
  /// copy, not derived data, so it is not reproduced here as a guess.
  String _subtitle(InstalledCapability capability) {
    final version = 'v${capability.version}';
    if (capability.requiresConsentFor.isNotEmpty) {
      return '$version · consent-gated · '
          '${capability.requiresConsentFor.join(', ')}';
    }
    final source = capability.isFirstParty ? 'first-party' : 'community';
    if (capability.itemCount > 0) {
      return '$version · $source · ${capability.itemCount} items';
    }
    return '$version · $source';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Text(
                'INSTALLED',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 2.2,
                  color: MindPalette.ink.withValues(alpha: 0.6),
                ),
              ),
              const Spacer(),
              Text(
                '${capabilities.length}',
                style: TextStyle(
                  fontSize: 10,
                  color: MindPalette.ink.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        ),
        for (final capability in capabilities)
          DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: MindPalette.grid)),
            ),
            child: InkWell(
              onTap: () => onTap(capability),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      _icons[capability.id] ?? Icons.extension_outlined,
                      size: 22,
                      color: MindPalette.local,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            capability.name,
                            style: const TextStyle(
                              fontSize: 14,
                              color: MindPalette.ink,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _subtitle(capability),
                            style: TextStyle(
                              fontSize: 11,
                              color: MindPalette.ink.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (capability.isActive)
                      const Text(
                        'ACTIVE',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.4,
                          color: MindPalette.local,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CommunitySection extends StatelessWidget {
  const _CommunitySection();

  static const _samples = [
    (icon: Icons.rocket_launch_outlined, name: 'Startup Runway'),
    (icon: Icons.directions_car_outlined, name: 'Vehicle Service Log'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'FROM THE COMMUNITY',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 2.2,
                    color: MindPalette.ink.withValues(alpha: 0.6),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'TIER 2 SANDBOX',
                style: TextStyle(
                  fontSize: 10,
                  color: MindPalette.ink.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
        ),
        // Fixed sample rows, not CapabilityPort data -- there is no
        // marketplace port. #1251 owns turning this into a real listing.
        for (final sample in _samples)
          DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: MindPalette.grid)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Icon(
                    sample.icon,
                    size: 22,
                    color: MindPalette.ink.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sample.name,
                          style: const TextStyle(
                            fontSize: 14,
                            color: MindPalette.ink,
                          ),
                        ),
                        Text(
                          'No network · no file access',
                          style: TextStyle(
                            fontSize: 11,
                            color: MindPalette.ink.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Disabled: no marketplace to install from yet (#1251).
                  InkWell(
                    onTap: null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: MindPalette.ink.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        'GET',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.4,
                          color: MindPalette.ink.withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _CapabilityDetailSheet extends StatelessWidget {
  const _CapabilityDetailSheet({
    required this.capability,
    required this.onRemove,
  });

  final InstalledCapability capability;
  final Future<void> Function() onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            capability.name,
            style: const TextStyle(
              fontFamily: 'AiroRulesExpanded',
              fontWeight: FontWeight.w700,
              fontSize: 19,
              color: MindPalette.ink,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'id ${capability.id} · v${capability.version}',
            style: TextStyle(
              fontSize: 12,
              color: MindPalette.ink.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 20),
          InkWell(
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: MindPalette.surface,
                  title: const Text(
                    'Remove this capability?',
                    style: TextStyle(color: MindPalette.ink),
                  ),
                  content: Text(
                    'Removing it does not remove the contexts it created. '
                    'Your data stays.',
                    style: TextStyle(
                      color: MindPalette.ink.withValues(alpha: 0.7),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('CANCEL'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text(
                        'REMOVE',
                        style: TextStyle(color: MindPalette.alarm),
                      ),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await onRemove();
                if (context.mounted) Navigator.of(context).pop(true);
              }
            },
            child: Container(
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(color: MindPalette.alarm),
              ),
              child: const Text(
                'REMOVE',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.8,
                  color: MindPalette.alarm,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
