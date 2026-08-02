import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

class SharedChannelImportScreen extends StatefulWidget {
  const SharedChannelImportScreen({
    required this.channelName,
    required this.sourceHost,
    required this.onSaveAndPlay,
    required this.onPlayOnce,
    required this.onCancel,
    super.key,
  });

  final String channelName;
  final String sourceHost;
  final Future<void> Function() onSaveAndPlay;
  final VoidCallback onPlayOnce;
  final VoidCallback onCancel;

  @override
  State<SharedChannelImportScreen> createState() =>
      _SharedChannelImportScreenState();
}

class _SharedChannelImportScreenState extends State<SharedChannelImportScreen> {
  bool _saving = false;
  String? _error;

  Future<void> _saveAndPlay() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSaveAndPlay();
      if (mounted) {
        setState(() => _saving = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save this channel. Try again or play it once.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      TvFocusable(
        semanticLabel: 'Save and play ${widget.channelName}',
        enabled: !_saving,
        onSelect: _saving ? null : _saveAndPlay,
        child: FilledButton.icon(
          key: const ValueKey('shared-channel-save-and-play'),
          onPressed: _saving ? null : _saveAndPlay,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.bookmark_add_outlined),
          label: Text(_saving ? 'Saving…' : 'Save & play'),
        ),
      ),
      TvFocusable(
        semanticLabel: 'Play ${widget.channelName} once',
        enabled: !_saving,
        onSelect: _saving ? null : widget.onPlayOnce,
        child: OutlinedButton.icon(
          key: const ValueKey('shared-channel-play-once'),
          onPressed: _saving ? null : widget.onPlayOnce,
          icon: const Icon(Icons.play_arrow),
          label: const Text('Play once'),
        ),
      ),
      TvFocusable(
        semanticLabel: 'Cancel shared channel',
        enabled: !_saving,
        onSelect: _saving ? null : widget.onCancel,
        child: TextButton(
          key: const ValueKey('shared-channel-cancel'),
          onPressed: _saving ? null : widget.onCancel,
          child: const Text('Cancel'),
        ),
      ),
    ];

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_saving) widget.onCancel();
      },
      child: AiroResponsiveScaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Card(
              margin: const EdgeInsets.all(24),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.live_tv, size: 40),
                    const SizedBox(height: 16),
                    Text(
                      'A friend shared ${widget.channelName}',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Adaptive HLS stream from ${widget.sourceHost}',
                      key: const ValueKey('shared-channel-source'),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Only add streams you have permission to watch.',
                    ),
                    if (_error case final error?) ...[
                      const SizedBox(height: 12),
                      Text(
                        error,
                        key: const ValueKey('shared-channel-error'),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Wrap(spacing: 12, runSpacing: 12, children: actions),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
