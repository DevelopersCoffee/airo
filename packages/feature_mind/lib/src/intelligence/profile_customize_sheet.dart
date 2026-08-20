import 'package:core_ai/core_ai.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/mind_palette.dart';
import 'ai_profile.dart';
import 'intelligence_providers.dart';
import 'intelligence_typography.dart';
import 'why_selected_sheet.dart';

Future<void> showProfileCustomizeSheet({
  required BuildContext context,
  required AiProfileReadiness readiness,
  required List<OfflineModelInfo> catalog,
}) {
  final compact = MediaQuery.sizeOf(context).width < 600;
  if (compact) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          backgroundColor: MindPalette.surface,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            title: Text(
              readiness.profile.title,
              style: IntelligenceTypography.cardTitle(Theme.of(context)),
            ),
          ),
          body: ProfileCustomizeView(readiness: readiness, catalog: catalog),
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: MindPalette.surface,
    showDragHandle: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.94,
      builder: (context, controller) => ProfileCustomizeView(
        readiness: readiness,
        catalog: catalog,
        scrollController: controller,
      ),
    ),
  );
}

class ProfileCustomizeView extends ConsumerWidget {
  const ProfileCustomizeView({
    super.key,
    required this.readiness,
    required this.catalog,
    this.scrollController,
  });

  final AiProfileReadiness readiness;
  final List<OfflineModelInfo> catalog;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final overrides = ref.watch(intelligenceOverridesProvider);
    final resolved = const AiProfileResolver().resolve(
      readiness.profile,
      catalog,
      constraints: IntelligenceConstraints(
        memory: ref.watch(intelligenceMemoryProvider),
      ),
      overrides: overrides,
    );

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text(
          resolved.profile.title.toUpperCase(),
          style: IntelligenceTypography.kicker(),
        ),
        const SizedBox(height: 8),
        Text(
          resolved.profile.jobLine,
          style: IntelligenceTypography.sectionTitle(theme),
        ),
        const SizedBox(height: 20),
        for (final slot in resolved.slots) ...[
          Text(slot.slot.label, style: IntelligenceTypography.cardTitle(theme)),
          const SizedBox(height: 8),
          _SlotChoice(
            profile: resolved.profile,
            slot: slot,
            selectedId:
                overrides['${resolved.profile.id.name}.${slot.slot.id}'],
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

class _SlotChoice extends ConsumerWidget {
  const _SlotChoice({
    required this.profile,
    required this.slot,
    required this.selectedId,
  });

  final AiProfile profile;
  final AiProfileSlotState slot;
  final String? selectedId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final automatic = selectedId == null;
    const query = IntelligenceQuery();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RadioListTile<bool>(
          value: true,
          groupValue: automatic,
          onChanged: (_) {
            unawaitedSet(ref, null);
          },
          title: Text(
            'Automatic',
            style: IntelligenceTypography.cardTitle(theme),
          ),
          subtitle: Text(
            'Best model for this device',
            style: IntelligenceTypography.secondary(theme),
          ),
          activeColor: MindPalette.local,
        ),
        if (slot.selection.model != null)
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Currently selected · ${slot.selection.model!.name}',
                    style: IntelligenceTypography.metadata(),
                  ),
                ),
                if (slot.selection.why != null)
                  TextButton(
                    onPressed: () =>
                        showWhySelectedSheet(context, slot.selection.why!),
                    child: const Text('Why?'),
                  ),
              ],
            ),
          ),
        for (final candidate in slot.selection.candidates.take(6))
          RadioListTile<String>(
            value: candidate.model.id,
            groupValue: selectedId,
            onChanged: (id) => unawaitedSet(ref, id),
            title: Text(
              candidate.model.name,
              style: IntelligenceTypography.body(theme),
            ),
            subtitle: Text(
              query.badgesFor(candidate.model).join(' · '),
              style: IntelligenceTypography.metadata(),
            ),
            activeColor: MindPalette.local,
          ),
      ],
    );
  }

  void unawaitedSet(WidgetRef ref, String? modelId) {
    ref
        .read(intelligenceOverridesProvider.notifier)
        .setOverride('${profile.id.name}.${slot.slot.id}', modelId);
  }
}
