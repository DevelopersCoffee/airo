import 'package:core_ai/core_ai.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../agent_chat/domain/models/assistant_runtime_ids.dart';
import '../../../widgets/mind_palette.dart';
import '../../../intelligence/ai_profile.dart';
import '../../../intelligence/intelligence_providers.dart';
import '../../../intelligence/intelligence_typography.dart';
import '../../../intelligence/profile_customize_sheet.dart';
import 'model_library_screen.dart';

/// First-run Chat gate: Automatic pick, or install recommended — never a
/// catalog of family names.
class ChatAutomaticGate extends ConsumerStatefulWidget {
  const ChatAutomaticGate({
    super.key,
    required this.library,
    required this.onModelSelected,
    required this.onOpenModelManager,
  });

  final AssistantModelLibraryState library;
  final ValueChanged<AssistantModelCandidate> onModelSelected;
  final VoidCallback onOpenModelManager;

  @override
  ConsumerState<ChatAutomaticGate> createState() => _ChatAutomaticGateState();
}

class _ChatAutomaticGateState extends ConsumerState<ChatAutomaticGate> {
  var _attempted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _trySelect());
  }

  @override
  void didUpdateWidget(ChatAutomaticGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_attempted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _trySelect());
    }
  }

  void _trySelect() {
    if (!mounted || _attempted) return;
    final candidate = automaticChatCandidate(
      library: widget.library,
      catalog: ref.read(intelligenceCatalogProvider),
      overrides: ref.read(intelligenceOverridesProvider),
    );
    if (candidate == null) return;
    _attempted = true;
    widget.onModelSelected(candidate);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final catalog = ref.watch(intelligenceCatalogProvider);
    final overrides = ref.watch(intelligenceOverridesProvider);
    final candidate = automaticChatCandidate(
      library: widget.library,
      catalog: catalog,
      overrides: overrides,
    );
    if (candidate != null) {
      return const AiroResponsiveScaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final readiness = const AiProfileResolver().resolve(
      AiProfile.generalChat,
      catalog,
      constraints: IntelligenceConstraints(
        memory: ref.watch(intelligenceMemoryProvider),
      ),
      overrides: overrides,
    );

    return AiroResponsiveScaffold(
      backgroundColor: MindPalette.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('CHAT', style: IntelligenceTypography.kicker()),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text('Automatic', style: IntelligenceTypography.pageTitle(theme)),
          const SizedBox(height: 8),
          Text(
            'Airo will pick a chat-capable model for this device. '
            'Nothing is selected until a package is installed.',
            style: IntelligenceTypography.body(theme),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: widget.onOpenModelManager,
            child: const Text('Install recommended'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => showProfileCustomizeSheet(
              context: context,
              readiness: readiness,
              catalog: catalog,
            ),
            child: const Text('Customize'),
          ),
        ],
      ),
    );
  }
}

AssistantModelCandidate? automaticChatCandidate({
  required AssistantModelLibraryState library,
  required List<OfflineModelInfo> catalog,
  required Map<String, String> overrides,
}) {
  final readiness = const AiProfileResolver().resolve(
    AiProfile.generalChat,
    catalog,
    overrides: overrides,
  );
  final picked = readiness.slots.first.selection.model;
  if (picked != null && picked.isDownloaded) {
    final id = assistantModelIdForOfflineModel(picked.id);
    final match = library.candidates
        .where((candidate) => candidate.id == id && candidate.available)
        .firstOrNull;
    if (match != null) return match;
  }
  final localReady = library.candidates.where(
    (candidate) => candidate.local && candidate.available,
  );
  if (localReady.isNotEmpty) return localReady.first;
  if (library.recommended.available) return library.recommended;
  return null;
}
