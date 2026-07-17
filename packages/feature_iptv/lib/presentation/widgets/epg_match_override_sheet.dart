import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_channels/platform_channels.dart';

import '../../application/providers/guide_providers.dart';

/// Lets the user manually set (or clear) which EPG channel id a specific
/// [IPTVChannel] should be matched against, for when tvg-id auto-matching
/// fails (CV-015 slice 2's explicit real-world IPTV pain point).
class EpgMatchOverrideSheet extends ConsumerStatefulWidget {
  const EpgMatchOverrideSheet({required this.channel, super.key});

  final IPTVChannel channel;

  @override
  ConsumerState<EpgMatchOverrideSheet> createState() => _EpgMatchOverrideSheetState();
}

class _EpgMatchOverrideSheetState extends ConsumerState<EpgMatchOverrideSheet> {
  final _idController = TextEditingController();
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    ref
        .read(epgChannelMatchOverrideStoreProvider)
        .resolveEpgChannelId(widget.channel.id)
        .then((existing) {
          if (mounted) {
            _idController.text = existing ?? widget.channel.id;
          }
        });
  }

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final id = _idController.text.trim();
    if (id.isEmpty) return;
    await ref.read(epgChannelMatchOverrideStoreProvider).setOverride(
      channelId: widget.channel.id,
      epgChannelId: id,
    );
    if (!mounted) return;
    ref.invalidate(guideEpgOverridesProvider);
  }

  Future<void> _clear() async {
    await ref.read(epgChannelMatchOverrideStoreProvider).clearOverride(widget.channel.id);
    if (!mounted) return;
    _idController.text = widget.channel.id;
    ref.invalidate(guideEpgOverridesProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Match "${widget.channel.name}" to EPG channel', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Default (no override): ${widget.channel.id}', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 12),
          TextField(
            controller: _idController,
            decoration: const InputDecoration(labelText: 'EPG channel id', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              FilledButton(onPressed: _save, child: const Text('Save')),
              const SizedBox(width: 8),
              TextButton(onPressed: _clear, child: const Text('Clear override')),
            ],
          ),
        ],
      ),
    );
  }
}
