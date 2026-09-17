import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/content_source_management_providers.dart';
import '../../application/providers/iptv_providers.dart';

/// Result of a successful Home URL import. Does not include the playlist URL
/// so callers cannot accidentally log it.
class TvPlaylistImportSummary {
  const TvPlaylistImportSummary({
    required this.playlistLabel,
    required this.channelCount,
    this.countries = const [],
    this.categories = const [],
  });

  final String playlistLabel;
  final int channelCount;
  final List<String> countries;
  final List<String> categories;
}

/// TV URL import panel. Fields sit above pinned Save/Cancel so the IME
/// cannot cover the actions.
class TvPlaylistUrlDialog extends ConsumerStatefulWidget {
  const TvPlaylistUrlDialog({super.key, this.initialUrl});

  final String? initialUrl;

  @override
  ConsumerState<TvPlaylistUrlDialog> createState() =>
      _TvPlaylistUrlDialogState();
}

class _TvPlaylistUrlDialogState extends ConsumerState<TvPlaylistUrlDialog> {
  late final TextEditingController _labelController;
  late final TextEditingController _urlController;
  final _labelFocusNode = FocusNode(debugLabel: 'tv-playlist-url-label');
  final _urlFocusNode = FocusNode(debugLabel: 'tv-playlist-url-url');
  bool _isSaving = false;
  String? _labelError;
  String? _urlError;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController();
    _urlController = TextEditingController(text: widget.initialUrl ?? '');
  }

  @override
  void dispose() {
    _labelController.dispose();
    _urlController.dispose();
    _labelFocusNode.dispose();
    _urlFocusNode.dispose();
    super.dispose();
  }

  String? _validateUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.host.isEmpty ||
        !(uri.isScheme('http') || uri.isScheme('https'))) {
      return 'Enter a valid http:// or https:// playlist URL.';
    }
    return null;
  }

  Future<void> _save() async {
    final label = _labelController.text.trim();
    final url = _urlController.text.trim();
    final labelError = label.isEmpty ? 'Enter a name for this playlist.' : null;
    final urlError = _validateUrl(url);
    if (labelError != null || urlError != null) {
      setState(() {
        _labelError = labelError;
        _urlError = urlError;
        _submitError = null;
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _labelError = null;
      _urlError = null;
      _submitError = null;
    });
    try {
      await ref.read(
        addM3uContentSourceProvider((label: label, url: url)).future,
      );
      if (!mounted) return;
      final channels = await ref.read(iptvChannelsProvider.future);
      if (!mounted) return;
      final countries = {
        for (final channel in channels)
          if (channel.country != null && channel.country!.isNotEmpty)
            channel.country!,
      }.toList(growable: false);
      final categories = {
        for (final channel in channels)
          if (channel.group.isNotEmpty) channel.group,
      }.take(3).toList(growable: false);
      Navigator.of(context).pop(
        TvPlaylistImportSummary(
          playlistLabel: label,
          channelCount: channels.length,
          countries: countries,
          categories: categories,
        ),
      );
    } on DuplicatePlaylistSourceException {
      if (!mounted) return;
      setState(() => _submitError = 'This playlist is already in your list.');
    } on ArgumentError catch (error) {
      if (!mounted) return;
      setState(() => _submitError = error.message.toString());
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitError = 'Could not add this playlist. Try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _cancel() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final viewInsets = MediaQuery.viewInsetsOf(context);

    return Scaffold(
      backgroundColor: colors.surface,
      resizeToAvoidBottomInset: false,
      body: Padding(
        padding: EdgeInsets.only(bottom: viewInsets.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AiroSpacing.lg,
                  AiroSpacing.lg,
                  AiroSpacing.lg,
                  AiroSpacing.md,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Or enter URL manually',
                      style: AiroTypography.titleLarge.copyWith(
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: AiroSpacing.sm),
                    Text(
                      'Paste an M3U URL for playlists you own or are '
                      'authorized to use.',
                      style: AiroTypography.bodyMedium.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AiroSpacing.lg),
                    TextField(
                      key: const ValueKey('tv-home-playlist-label-field'),
                      controller: _labelController,
                      focusNode: _labelFocusNode,
                      autofocus: true,
                      enabled: !_isSaving,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Playlist name',
                        errorText: _labelError,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: AiroSpacing.md),
                    TextField(
                      key: const ValueKey('tv-home-playlist-url-field'),
                      controller: _urlController,
                      focusNode: _urlFocusNode,
                      enabled: !_isSaving,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _isSaving ? null : _save(),
                      decoration: InputDecoration(
                        labelText: 'M3U playlist URL',
                        errorText: _urlError,
                        prefixIcon: const Icon(Icons.link),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    if (_submitError != null) ...[
                      const SizedBox(height: AiroSpacing.sm),
                      Text(
                        _submitError!,
                        style: AiroTypography.bodyMedium.copyWith(
                          color: colors.error,
                        ),
                      ),
                    ],
                    if (_isSaving) ...[
                      const SizedBox(height: AiroSpacing.md),
                      const LinearProgressIndicator(),
                    ],
                  ],
                ),
              ),
            ),
            Material(
              color: colors.surface,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AiroSpacing.lg,
                  AiroSpacing.sm,
                  AiroSpacing.lg,
                  AiroSpacing.md,
                ),
                child: Row(
                  children: [
                    const Spacer(),
                    TvFocusable(
                      semanticLabel: 'Cancel',
                      onSelect: _isSaving ? null : _cancel,
                      borderRadius: AiroSpacing.radiusSm,
                      child: SizedBox(
                        height: AiroSpacing.tvMinTarget,
                        child: TextButton(
                          onPressed: _isSaving ? null : _cancel,
                          child: const Text('Cancel'),
                        ),
                      ),
                    ),
                    const SizedBox(width: AiroSpacing.sm),
                    TvFocusable(
                      semanticLabel: 'Save playlist URL',
                      onSelect: _isSaving ? null : _save,
                      borderRadius: AiroSpacing.radiusSm,
                      child: SizedBox(
                        height: AiroSpacing.tvMinTarget,
                        child: FilledButton(
                          onPressed: _isSaving ? null : _save,
                          child: Text(_isSaving ? 'Saving…' : 'Save'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
