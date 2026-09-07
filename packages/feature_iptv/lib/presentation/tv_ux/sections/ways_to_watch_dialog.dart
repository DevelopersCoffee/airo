import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

class WaysToWatchDialog extends StatelessWidget {
  const WaysToWatchDialog({
    super.key,
    required this.pictureInPictureSupported,
    this.showCast = true,
    required this.castAvailable,
    required this.onFitScreen,
    required this.onFullScreen,
    required this.onPictureInPicture,
    required this.onCast,
    required this.onCastMultiview,
  });

  final bool pictureInPictureSupported;
  final bool showCast;
  final bool castAvailable;
  final VoidCallback onFitScreen;
  final VoidCallback onFullScreen;
  final VoidCallback onPictureInPicture;
  final VoidCallback onCast;

  /// Opens the Cast MultiView remote-control screen — a phone remote for a
  /// TV's MultiView grid, distinct from casting this one channel. See
  /// docs/superpowers/specs/2026-09-07-cast-multiview-remote-control-spec.md.
  final VoidCallback onCastMultiview;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey('ways-to-watch-dialog'),
      title: const Text('Ways to Watch'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SectionLabel('ON THIS DEVICE'),
              _WatchOption(
                key: const ValueKey('ways-to-watch-fit'),
                icon: Icons.fit_screen_outlined,
                title: 'Fit Screen',
                description: 'Keep video fitted inside the Aika Stream window.',
                autofocus: true,
                onSelect: onFitScreen,
              ),
              _WatchOption(
                key: const ValueKey('ways-to-watch-fullscreen'),
                icon: Icons.fullscreen,
                title: 'Full Screen',
                description: 'Fill this display and hide the browsing shell.',
                onSelect: onFullScreen,
              ),
              if (pictureInPictureSupported)
                _WatchOption(
                  key: const ValueKey('ways-to-watch-pip'),
                  icon: Icons.picture_in_picture_alt_outlined,
                  title: 'Floating Window',
                  description: 'Keep video visible while using other apps.',
                  onSelect: onPictureInPicture,
                ),
              if (showCast) ...[
                const Divider(height: 28),
                const _SectionLabel('ON ANOTHER SCREEN'),
                _WatchOption(
                  key: const ValueKey('ways-to-watch-cast'),
                  icon: Icons.cast,
                  title: 'Cast to TV',
                  description: castAvailable
                      ? 'Choose a nearby Cast-enabled TV.'
                      : 'No Cast devices available.',
                  onSelect: castAvailable ? onCast : null,
                ),
                _WatchOption(
                  key: const ValueKey('ways-to-watch-cast-multiview'),
                  icon: Icons.grid_view_rounded,
                  title: 'Cast MultiView',
                  description: 'Remote-control a TV\'s MultiView grid.',
                  onSelect: onCastMultiview,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('ways-to-watch-close'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _WatchOption extends StatelessWidget {
  const _WatchOption({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onSelect,
    this.autofocus = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback? onSelect;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TvFocusable(
      semanticLabel: title,
      autofocus: autofocus,
      enabled: onSelect != null,
      onSelect: onSelect,
      borderRadius: 8,
      child: ListTile(
        enabled: onSelect != null,
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(description, maxLines: 1),
        onTap: onSelect,
      ),
    );
  }
}
