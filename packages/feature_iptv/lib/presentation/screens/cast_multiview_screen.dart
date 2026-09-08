import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_player/platform_player.dart';

import '../../application/providers/cast_multiview_layouts_provider.dart';
import '../../application/providers/cast_multiview_sender_provider.dart';
import '../../application/providers/iptv_providers.dart';
import '../tv_ux/sections/multiview_layout_picker.dart';
import '../widgets/adaptive_iptv_sheet.dart';

/// Phone-side remote control for a TV's MultiView grid — a distinct
/// section from normal channel browsing/single-channel casting, per
/// docs/superpowers/specs/2026-09-07-cast-multiview-remote-control-spec.md.
///
/// Works against [multiviewCastSenderTransportProvider], which defaults to
/// [UnavailableMultiviewCastSenderTransport] until Cast Connect's native
/// wiring exists (see the spec's Dependencies) — every action here is real
/// and tested against that transport contract, but nothing actually
/// reaches a TV yet.
class CastMultiviewScreen extends ConsumerWidget {
  const CastMultiviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receiverState = ref.watch(multiviewCastReceiverStateProvider);
    final layouts = ref.watch(multiviewCastLayoutsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Cast MultiView')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ConnectionCard(receiverState: receiverState),
          const SizedBox(height: 24),
          Text('Layouts', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _LayoutPicker(receiverState: receiverState),
          const SizedBox(height: 24),
          Text('On the TV now', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          receiverState.when(
            data: (state) => state == null
                ? const _EmptyLiveGrid()
                : _LiveGrid(state: state),
            loading: () => const Center(
              key: ValueKey('cast-multiview-live-loading'),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (error, stackTrace) => const _EmptyLiveGrid(),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Saved layouts',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              TextButton.icon(
                key: const ValueKey('cast-multiview-create-layout'),
                onPressed: () => _openLayoutEditor(context),
                icon: const Icon(Icons.add),
                label: const Text('Create layout'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          layouts.when(
            data: (savedLayouts) => _SavedLayoutsList(layouts: savedLayouts),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) =>
                Text('Could not load layouts: $error'),
          ),
        ],
      ),
    );
  }

  Future<void> _openLayoutEditor(BuildContext context) {
    return showAdaptiveIptvSheet<void>(
      context: context,
      builder: (_) => const CastMultiviewLayoutEditorSheet(),
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({required this.receiverState});

  final AsyncValue<MultiviewCastState?> receiverState;

  @override
  Widget build(BuildContext context) {
    final hasReceiver = receiverState.value != null;
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: hasReceiver
          ? colors.primaryContainer
          : colors.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              hasReceiver ? Icons.cast_connected : Icons.cast,
              color: hasReceiver
                  ? colors.onPrimaryContainer
                  : colors.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                hasReceiver
                    ? 'TV Connected'
                    : 'Not connected — pick a TV from Cast to control its '
                          'MultiView grid.',
                style: TextStyle(
                  color: hasReceiver
                      ? colors.onPrimaryContainer
                      : colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LayoutPicker extends ConsumerWidget {
  const _LayoutPicker({required this.receiverState});

  final AsyncValue<MultiviewCastState?> receiverState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = receiverState.value;
    final sender = ref.read(multiviewCastSenderTransportProvider);
    return MultiviewLayoutPicker(
      selected: state?.layout,
      capacity: state?.capacity ?? kAiroMultiviewHardCap,
      onSelected: (kind) =>
          sender.sendCommand(MultiviewSetLayoutCommand(layout: kind)),
    );
  }
}

class _EmptyLiveGrid extends StatelessWidget {
  const _EmptyLiveGrid();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Nothing on screen yet.',
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _LiveGrid extends ConsumerWidget {
  const _LiveGrid({required this.state});

  final MultiviewCastState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.slots.isEmpty) return const _EmptyLiveGrid();
    final sender = ref.read(multiviewCastSenderTransportProvider);
    return Column(
      children: [
        for (final slot in state.slots)
          Card(
            key: ValueKey('cast-multiview-live-slot-${slot.slotId}'),
            child: ListTile(
              leading: Icon(slot.featured ? Icons.volume_up : Icons.volume_off),
              title: Text(slot.channelName),
              subtitle: Text(slot.featured ? 'Featured' : 'Muted tile'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!slot.featured)
                    IconButton(
                      tooltip: 'Focus audio here',
                      icon: const Icon(Icons.hearing),
                      onPressed: () => sender.sendCommand(
                        MultiviewPromoteCommand(slotId: slot.slotId),
                      ),
                    ),
                  IconButton(
                    tooltip: 'Remove from grid',
                    icon: const Icon(Icons.close),
                    onPressed: () => sender.sendCommand(
                      MultiviewRemoveSlotCommand(slotId: slot.slotId),
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

class _SavedLayoutsList extends ConsumerWidget {
  const _SavedLayoutsList({required this.layouts});

  final List<MultiviewCastLayout> layouts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (layouts.isEmpty) {
      return Text(
        'No saved layouts yet — build one with "Create layout".',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }
    final sender = ref.read(multiviewCastSenderTransportProvider);
    final deleteLayout = ref.read(deleteMultiviewCastLayoutProvider);
    return Column(
      children: [
        for (final layout in layouts)
          Card(
            key: ValueKey('cast-multiview-layout-${layout.id}'),
            child: ListTile(
              title: Text(layout.name),
              subtitle: Text(
                layout.slots.map((slot) => slot.channelName).join(' · '),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Launch on TV',
                    icon: const Icon(Icons.play_arrow),
                    onPressed: () async {
                      if (layout.layout != null) {
                        await sender.sendCommand(
                          MultiviewSetLayoutCommand(layout: layout.layout!),
                        );
                      }
                      for (final slot in layout.slots) {
                        await sender.sendCommand(
                          MultiviewSetSlotCommand(
                            slotId: slot.channelId,
                            channelId: slot.channelId,
                          ),
                        );
                      }
                    },
                  ),
                  IconButton(
                    tooltip: 'Delete layout',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => deleteLayout(layout.id),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Builds a new named layout: pick channels from the current playlist, then
/// save. A simple inline search — the TV-side long-list picker
/// (`filter_dialogs.dart`) is a ten-foot-UI concern this phone screen
/// doesn't share.
class CastMultiviewLayoutEditorSheet extends ConsumerStatefulWidget {
  const CastMultiviewLayoutEditorSheet({super.key});

  @override
  ConsumerState<CastMultiviewLayoutEditorSheet> createState() =>
      _CastMultiviewLayoutEditorSheetState();
}

class _CastMultiviewLayoutEditorSheetState
    extends ConsumerState<CastMultiviewLayoutEditorSheet> {
  final _nameController = TextEditingController();
  final _selected = <MultiviewCastLayoutSlot>[];
  MultiviewLayoutKind? _layout;

  @override
  void initState() {
    super.initState();
    // The Save button's enabled state depends on the name field's text —
    // rebuild on every keystroke, not only when a channel checkbox toggles.
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final channels = ref.watch(iptvChannelsProvider);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create layout',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const ValueKey('cast-multiview-layout-name'),
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Layout name',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Arrangement',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    MultiviewLayoutPicker(
                      selected: _layout,
                      capacity: kAiroMultiviewHardCap,
                      onSelected: (kind) => setState(() => _layout = kind),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Channels (${_selected.length})',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final slot in _selected)
                          Chip(
                            key: ValueKey(
                              'cast-multiview-slot-chip-${slot.channelId}',
                            ),
                            label: Text(slot.channelName),
                            onDeleted: () => setState(
                              () => _selected.removeWhere(
                                (s) => s.channelId == slot.channelId,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    channels.when(
                      data: (available) => SizedBox(
                        height: 160,
                        child: ListView(
                          children: [
                            for (final channel in available)
                              CheckboxListTile(
                                key: ValueKey(
                                  'cast-multiview-channel-option-${channel.id}',
                                ),
                                value: _selected.any(
                                  (s) => s.channelId == channel.id,
                                ),
                                title: Text(channel.name),
                                onChanged: (checked) => setState(() {
                                  if (checked == true) {
                                    _selected.add(
                                      MultiviewCastLayoutSlot(
                                        channelId: channel.id,
                                        channelName: channel.name,
                                      ),
                                    );
                                  } else {
                                    _selected.removeWhere(
                                      (s) => s.channelId == channel.id,
                                    );
                                  }
                                }),
                              ),
                          ],
                        ),
                      ),
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, stackTrace) =>
                          Text('Could not load channels: $error'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  key: const ValueKey('cast-multiview-save-layout'),
                  onPressed: _canSave ? _save : null,
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool get _canSave =>
      _nameController.text.trim().isNotEmpty && _selected.isNotEmpty;

  Future<void> _save() async {
    final save = ref.read(saveMultiviewCastLayoutProvider);
    await save(
      MultiviewCastLayout(
        id: newMultiviewCastLayoutId(),
        name: _nameController.text.trim(),
        layout: _layout,
        slots: List.unmodifiable(_selected),
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }
}
