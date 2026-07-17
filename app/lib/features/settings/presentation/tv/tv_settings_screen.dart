import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_ui/core_ui.dart';

enum _TvSettingsSection { theme, playback, sources, accessibility }

/// TV Settings screen (CV-022): a left-hand section list, right-hand detail
/// pane. Task 3 stubs each pane; Tasks 4-6 replace the stubs with real
/// section widgets (`TvThemeSection`, `TvPlaybackSection`,
/// `TvSourceManagementSection`).
class TvSettingsScreen extends ConsumerStatefulWidget {
  const TvSettingsScreen({super.key});

  @override
  ConsumerState<TvSettingsScreen> createState() => _TvSettingsScreenState();
}

class _TvSettingsScreenState extends ConsumerState<TvSettingsScreen> {
  _TvSettingsSection _selected = _TvSettingsSection.theme;

  static const _sections = [
    (_TvSettingsSection.theme, 'Theme', Icons.palette_outlined),
    (_TvSettingsSection.playback, 'Playback', Icons.play_circle_outline),
    (_TvSettingsSection.sources, 'Sources', Icons.dns_outlined),
    (
      _TvSettingsSection.accessibility,
      'Accessibility',
      Icons.accessibility_new_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Row(
          children: [
            SizedBox(
              width: 260,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final (section, label, icon) in _sections)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TvFocusable(
                        autofocus: section == _TvSettingsSection.theme,
                        onSelect: () => setState(() => _selected = section),
                        semanticLabel: label,
                        semanticButton: true,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: section == _selected
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Icon(icon, color: Colors.white),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    label,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: _buildDetail(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetail() {
    switch (_selected) {
      case _TvSettingsSection.theme:
        return const SizedBox(key: ValueKey('tv_settings_section_theme'));
      case _TvSettingsSection.playback:
        return const SizedBox(key: ValueKey('tv_settings_section_playback'));
      case _TvSettingsSection.sources:
        return const SizedBox(key: ValueKey('tv_settings_section_sources'));
      case _TvSettingsSection.accessibility:
        return const _AccessibilityComingSoon();
    }
  }
}

class _AccessibilityComingSoon extends StatelessWidget {
  const _AccessibilityComingSoon();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Accessibility', style: TextStyle(color: Colors.white, fontSize: 20)),
          SizedBox(height: 8),
          Text('Coming soon', style: TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}
