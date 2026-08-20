import 'package:core_ai/core_ai.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../widgets/mind_palette.dart';
import 'ai_profile.dart';
import 'intelligence_providers.dart';
import 'intelligence_typography.dart';
import 'profile_customize_sheet.dart';
import 'why_selected_sheet.dart';

enum IntelligenceSection {
  overview,
  capabilities,
  models,
  library,
  diagnostics,
}

/// Task-first control center. Nested sections stay inside Intelligence.
class IntelligenceHomeScreen extends ConsumerStatefulWidget {
  const IntelligenceHomeScreen({
    super.key,
    this.modelsTab,
    this.libraryTab,
    this.diagnosticsTab,
    this.onOpenChat,
    this.onOpenScribe,
    this.onInstallModels,
    this.onOpenModels,
    this.embedded = false,
  });

  final Widget? modelsTab;
  final Widget? libraryTab;
  final Widget? diagnosticsTab;
  final VoidCallback? onOpenChat;
  final VoidCallback? onOpenScribe;
  final Future<void> Function(List<OfflineModelInfo> models)? onInstallModels;
  final VoidCallback? onOpenModels;
  final bool embedded;

  @override
  ConsumerState<IntelligenceHomeScreen> createState() =>
      _IntelligenceHomeScreenState();
}

class _IntelligenceHomeScreenState
    extends ConsumerState<IntelligenceHomeScreen> {
  IntelligenceSection _section = IntelligenceSection.overview;
  AiProfileReadiness? _selected;
  static const _resolver = AiProfileResolver();
  static const _query = IntelligenceQuery();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 600;
    final split = width >= 600;
    final theme = Theme.of(context);
    final catalog = ref.watch(intelligenceCatalogProvider);
    final memory = ref.watch(intelligenceMemoryProvider);
    final overrides = ref.watch(intelligenceOverridesProvider);
    final constraints = IntelligenceConstraints(memory: memory);
    final profiles = _resolver.overviewProfiles(
      catalog,
      constraints: constraints,
    );
    final readiness = {
      for (final profile in profiles)
        profile.id: _resolver.resolve(
          profile,
          catalog,
          constraints: constraints,
          overrides: overrides,
        ),
    };
    final capabilities = _query.capabilitiesPresent(
      catalog,
      constraints: constraints,
    );
    final sectionTitle = switch (_section) {
      IntelligenceSection.overview => 'Intelligence',
      IntelligenceSection.capabilities => 'Capabilities',
      IntelligenceSection.models => 'Models',
      IntelligenceSection.library => 'Library',
      IntelligenceSection.diagnostics => 'Diagnostics',
    };

    return AiroResponsiveScaffold(
      backgroundColor: MindPalette.surface,
      maxWidth: width >= 1440 ? 1440 : 1200,
      appBar: widget.embedded
          ? null
          : AppBar(
              backgroundColor: Colors.transparent,
              leading: compact && _section != IntelligenceSection.overview
                  ? BackButton(
                      onPressed: () => setState(
                        () => _section = IntelligenceSection.overview,
                      ),
                    )
                  : null,
              title: Text(
                compact ? sectionTitle : 'INTELLIGENCE',
                style: compact
                    ? IntelligenceTypography.cardTitle(theme)
                    : IntelligenceTypography.kicker(),
              ),
            ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!compact)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: _SectionChips(
                section: _section,
                onChanged: (section) {
                  if (section == IntelligenceSection.models &&
                      widget.modelsTab == null) {
                    widget.onOpenModels?.call();
                    return;
                  }
                  setState(() {
                    _section = section;
                    _selected = null;
                  });
                },
                showModels:
                    widget.modelsTab != null || widget.onOpenModels != null,
                showLibrary: widget.libraryTab != null,
                showDiagnostics: widget.diagnosticsTab != null,
              ),
            ),
          Expanded(
            child:
                split &&
                    _section == IntelligenceSection.overview &&
                    _selected != null
                ? Row(
                    children: [
                      Expanded(
                        child: _buildSection(
                          compact,
                          readiness,
                          catalog,
                          capabilities,
                        ),
                      ),
                      const VerticalDivider(width: 1),
                      SizedBox(
                        width: 360,
                        child: ProfileCustomizeView(
                          readiness: _selected!,
                          catalog: catalog,
                        ),
                      ),
                    ],
                  )
                : _buildSection(compact, readiness, catalog, capabilities),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    bool compact,
    Map<AiProfileId, AiProfileReadiness> readiness,
    List<OfflineModelInfo> catalog,
    List<ModelCapability> capabilities,
  ) {
    if (compact && _section == IntelligenceSection.overview) {
      return _OverviewBody(
        compact: true,
        readiness: readiness,
        catalog: catalog,
        storageUsedBytes: ref.watch(intelligenceStorageUsedBytesProvider),
        memory: ref.watch(intelligenceMemoryProvider),
        onOpenProfile: _openProfile,
        onCustomize: _customize,
        onInstallRecommended: () => _installRecommended(readiness),
        onOpenAdvanced: (section) {
          if (section == IntelligenceSection.models &&
              widget.modelsTab == null) {
            widget.onOpenModels?.call();
            return;
          }
          setState(() => _section = section);
        },
        showModels: widget.modelsTab != null || widget.onOpenModels != null,
        showLibrary: widget.libraryTab != null,
        showDiagnostics: widget.diagnosticsTab != null,
      );
    }

    return switch (_section) {
      IntelligenceSection.overview => _OverviewBody(
        compact: false,
        readiness: readiness,
        catalog: catalog,
        storageUsedBytes: ref.watch(intelligenceStorageUsedBytesProvider),
        memory: ref.watch(intelligenceMemoryProvider),
        onOpenProfile: _openProfile,
        onCustomize: _customize,
        onInstallRecommended: () => _installRecommended(readiness),
      ),
      IntelligenceSection.capabilities => _CapabilitiesBody(
        capabilities: capabilities,
        catalog: catalog,
        memory: ref.watch(intelligenceMemoryProvider),
        overrides: ref.watch(intelligenceOverridesProvider),
        onCustomize: _customize,
      ),
      IntelligenceSection.models => widget.modelsTab ?? const SizedBox.shrink(),
      IntelligenceSection.library =>
        widget.libraryTab ?? const SizedBox.shrink(),
      IntelligenceSection.diagnostics =>
        widget.diagnosticsTab ?? const SizedBox.shrink(),
    };
  }

  void _customize(AiProfileReadiness readiness) {
    final split = MediaQuery.sizeOf(context).width >= 600;
    if (split && _section == IntelligenceSection.overview) {
      setState(() => _selected = readiness);
      return;
    }
    showProfileCustomizeSheet(
      context: context,
      readiness: readiness,
      catalog: ref.read(intelligenceCatalogProvider),
    );
  }

  void _openProfile(AiProfileReadiness readiness) {
    if (!readiness.ready) {
      _customize(readiness);
      return;
    }
    switch (readiness.profile.id) {
      case AiProfileId.meetingAssistant:
      case AiProfileId.voiceTranscription:
        if (widget.onOpenScribe != null) {
          widget.onOpenScribe!();
        } else {
          context.go(readiness.profile.destinationPath);
        }
      case AiProfileId.generalChat:
      case AiProfileId.documentAssistant:
      case AiProfileId.imageAssistant:
        if (widget.onOpenChat != null) {
          widget.onOpenChat!();
        } else {
          context.go(readiness.profile.destinationPath);
        }
    }
  }

  Future<void> _installRecommended(
    Map<AiProfileId, AiProfileReadiness> readiness,
  ) async {
    final models = <String, OfflineModelInfo>{};
    for (final item in readiness.values) {
      for (final model in item.recommendedInstalls) {
        models[model.id] = model;
      }
    }
    if (models.isEmpty) return;
    await widget.onInstallModels?.call(models.values.toList(growable: false));
  }
}

class _SectionChips extends StatelessWidget {
  const _SectionChips({
    required this.section,
    required this.onChanged,
    required this.showModels,
    required this.showLibrary,
    required this.showDiagnostics,
  });

  final IntelligenceSection section;
  final ValueChanged<IntelligenceSection> onChanged;
  final bool showModels;
  final bool showLibrary;
  final bool showDiagnostics;

  @override
  Widget build(BuildContext context) {
    final items = <(IntelligenceSection, String)>[
      (IntelligenceSection.overview, 'Overview'),
      (IntelligenceSection.capabilities, 'Capabilities'),
      if (showModels) (IntelligenceSection.models, 'Models'),
      if (showLibrary) (IntelligenceSection.library, 'Library'),
      if (showDiagnostics) (IntelligenceSection.diagnostics, 'Diagnostics'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(item.$2, style: IntelligenceTypography.status()),
                selected: section == item.$1,
                onSelected: (_) => onChanged(item.$1),
                selectedColor: MindPalette.local.withValues(alpha: 0.22),
              ),
            ),
        ],
      ),
    );
  }
}

class _OverviewBody extends StatelessWidget {
  const _OverviewBody({
    required this.compact,
    required this.readiness,
    required this.catalog,
    required this.storageUsedBytes,
    required this.memory,
    required this.onOpenProfile,
    required this.onCustomize,
    required this.onInstallRecommended,
    this.onOpenAdvanced,
    this.showModels = false,
    this.showLibrary = false,
    this.showDiagnostics = false,
  });

  final bool compact;
  final Map<AiProfileId, AiProfileReadiness> readiness;
  final List<OfflineModelInfo> catalog;
  final int storageUsedBytes;
  final MemoryInfo? memory;
  final ValueChanged<AiProfileReadiness> onOpenProfile;
  final ValueChanged<AiProfileReadiness> onCustomize;
  final VoidCallback onInstallRecommended;
  final ValueChanged<IntelligenceSection>? onOpenAdvanced;
  final bool showModels;
  final bool showLibrary;
  final bool showDiagnostics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profiles = readiness.values.toList(growable: false);
    final readyCount = profiles.where((item) => item.ready).length;
    final missing = profiles.any((item) => !item.ready && item.canInstall);
    final columns = compact
        ? 1
        : MediaQuery.sizeOf(context).width >= 1440
        ? 4
        : 2;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Text('INTELLIGENCE', style: IntelligenceTypography.kicker()),
        const SizedBox(height: 8),
        Text(
          'What do you want Airo to do?',
          style: IntelligenceTypography.pageTitle(theme),
        ),
        const SizedBox(height: 6),
        Text(
          'Your AI runs locally. Airo selects the right models for each task.',
          style: IntelligenceTypography.body(
            theme,
          ).copyWith(color: MindPalette.ink.withValues(alpha: 0.78)),
        ),
        const SizedBox(height: 24),
        Text('READY', style: IntelligenceTypography.kicker()),
        const SizedBox(height: 4),
        Text(
          '$readyCount ${readyCount == 1 ? 'capability' : 'capabilities'} available',
          style: IntelligenceTypography.metadata(),
        ),
        const SizedBox(height: 12),
        if (compact) ...[
          for (final profile in profiles)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _CapabilityCard(
                readiness: profile,
                onOpen: () => onOpenProfile(profile),
                onCustomize: () => onCustomize(profile),
                fillHeight: false,
              ),
            ),
        ] else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: profiles.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: MediaQuery.sizeOf(context).width >= 1440
                  ? 1.25
                  : 1.15,
            ),
            itemBuilder: (context, index) => _CapabilityCard(
              readiness: profiles[index],
              onOpen: () => onOpenProfile(profiles[index]),
              onCustomize: () => onCustomize(profiles[index]),
            ),
          ),
        if (missing) ...[
          const SizedBox(height: 24),
          _RecommendedSetupCard(
            profiles: profiles,
            onApply: onInstallRecommended,
          ),
        ],
        const SizedBox(height: 28),
        Text('SYSTEM', style: IntelligenceTypography.kicker()),
        const SizedBox(height: 12),
        _SystemRow(
          label: 'Models installed',
          value: '${catalog.where((model) => model.isDownloaded).length}',
        ),
        _SystemRow(
          label: 'Storage used',
          value: _formatBytes(storageUsedBytes),
        ),
        _SystemRow(
          label: 'Memory available',
          value: memory == null || !memory!.isAvailable
              ? 'Unknown'
              : '${memory!.availableGB.toStringAsFixed(1)} GB',
        ),
        _SystemRow(label: 'Runtime', value: _runtimeLabel(catalog)),
        if (compact) ...[
          const SizedBox(height: 28),
          Text('ADVANCED', style: IntelligenceTypography.kicker()),
          const SizedBox(height: 8),
          _AdvancedTile(
            title: 'Capabilities',
            onTap: () => onOpenAdvanced?.call(IntelligenceSection.capabilities),
          ),
          if (showModels)
            _AdvancedTile(
              title: 'Models',
              onTap: () => onOpenAdvanced?.call(IntelligenceSection.models),
            ),
          if (showLibrary)
            _AdvancedTile(
              title: 'Library',
              onTap: () => onOpenAdvanced?.call(IntelligenceSection.library),
            ),
          if (showDiagnostics)
            _AdvancedTile(
              title: 'Diagnostics',
              onTap: () =>
                  onOpenAdvanced?.call(IntelligenceSection.diagnostics),
            ),
        ],
      ],
    );
  }

  String _runtimeLabel(List<OfflineModelInfo> catalog) {
    final downloaded = catalog.where((model) => model.isDownloaded);
    if (downloaded.isEmpty) return 'None';
    return downloaded.first.effectiveRuntime.displayName;
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
}

class _CapabilityCard extends StatelessWidget {
  const _CapabilityCard({
    required this.readiness,
    required this.onOpen,
    required this.onCustomize,
    this.fillHeight = true,
  });

  final AiProfileReadiness readiness;
  final VoidCallback onOpen;
  final VoidCallback onCustomize;
  final bool fillHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = readiness.ready
        ? 'Ready'
        : readiness.canInstall
        ? 'Install'
        : 'Not available';
    final statusColor = readiness.ready
        ? MindPalette.local
        : readiness.canInstall
        ? MindPalette.ink
        : MindPalette.ink.withValues(alpha: 0.45);

    return Material(
      color: MindPalette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: MindPalette.grid),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: fillHeight ? MainAxisSize.max : MainAxisSize.min,
            children: [
              Text(
                readiness.profile.title.toUpperCase(),
                style: IntelligenceTypography.kicker(),
              ),
              const SizedBox(height: 8),
              Text(
                readiness.profile.jobLine,
                style: IntelligenceTypography.cardTitle(theme),
              ),
              if (fillHeight) const Spacer() else const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    status,
                    style: IntelligenceTypography.status(statusColor),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: onCustomize,
                    child: const Text('Customize'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecommendedSetupCard extends StatelessWidget {
  const _RecommendedSetupCard({required this.profiles, required this.onApply});

  final List<AiProfileReadiness> profiles;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MindPalette.local.withValues(alpha: 0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('RECOMMENDED', style: IntelligenceTypography.kicker()),
            const SizedBox(height: 8),
            Text('Airo Daily', style: IntelligenceTypography.cardTitle(theme)),
            const SizedBox(height: 12),
            for (final profile in profiles)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        profile.profile.title,
                        style: IntelligenceTypography.body(theme),
                      ),
                    ),
                    Text(
                      profile.ready ? 'Ready' : 'Install',
                      style: IntelligenceTypography.metadata(
                        profile.ready ? MindPalette.local : MindPalette.ink,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onApply,
              child: const Text('Apply recommended setup'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CapabilitiesBody extends StatelessWidget {
  const _CapabilitiesBody({
    required this.capabilities,
    required this.catalog,
    required this.memory,
    required this.overrides,
    required this.onCustomize,
  });

  final List<ModelCapability> capabilities;
  final List<OfflineModelInfo> catalog;
  final MemoryInfo? memory;
  final Map<String, String> overrides;
  final ValueChanged<AiProfileReadiness> onCustomize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const query = IntelligenceQuery();
    const resolver = AiProfileResolver();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Text('CAPABILITIES', style: IntelligenceTypography.kicker()),
        const SizedBox(height: 8),
        Text(
          'Each capability defaults to Automatic.',
          style: IntelligenceTypography.body(theme),
        ),
        const SizedBox(height: 16),
        for (final capability in capabilities)
          Builder(
            builder: (context) {
              final selection = query.select(
                capability: capability,
                catalog: catalog,
                constraints: IntelligenceConstraints(memory: memory),
              );
              final profile = AiProfile.catalog
                  .where(
                    (item) =>
                        item.slots.any((slot) => slot.capability == capability),
                  )
                  .firstOrNull;
              return Card(
                color: MindPalette.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: MindPalette.grid),
                ),
                child: ListTile(
                  title: Text(
                    capability.displayName,
                    style: IntelligenceTypography.cardTitle(theme),
                  ),
                  subtitle: Text(
                    '${AiProfileResolver.jobLineFor(capability)} · '
                    '${selection.ready ? 'Automatic · Ready' : 'Automatic · Not ready'}',
                    style: IntelligenceTypography.metadata(),
                  ),
                  trailing: TextButton(
                    onPressed: () {
                      final why = selection.why;
                      if (why != null) showWhySelectedSheet(context, why);
                    },
                    child: const Text('Why?'),
                  ),
                  onTap: profile == null
                      ? null
                      : () => onCustomize(
                          resolver.resolve(
                            profile,
                            catalog,
                            constraints: IntelligenceConstraints(
                              memory: memory,
                            ),
                            overrides: overrides,
                          ),
                        ),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _SystemRow extends StatelessWidget {
  const _SystemRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: IntelligenceTypography.secondary(Theme.of(context)),
            ),
          ),
          Text(value, style: IntelligenceTypography.metadata()),
        ],
      ),
    );
  }
}

class _AdvancedTile extends StatelessWidget {
  const _AdvancedTile({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: IntelligenceTypography.cardTitle(Theme.of(context)),
      ),
      trailing: const Icon(Icons.chevron_right, color: MindPalette.ink),
      onTap: onTap,
    );
  }
}
