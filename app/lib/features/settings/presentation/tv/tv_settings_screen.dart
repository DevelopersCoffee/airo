import 'package:core_product_shell/core_product_shell.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_ui/core_ui.dart';

import 'tv_playback_section.dart';
import 'tv_source_management_section.dart';
import 'tv_theme_section.dart';

/// TV Settings screen (CV-022): a left-hand section list, right-hand detail
/// pane. Tasks 5-6 replace the remaining stubs with real section widgets
/// (`TvPlaybackSection`, `TvSourceManagementSection`). Section names/icons
/// come from the shared `iptvSettingsSections` manifest (SSOT with the
/// mobile settings hub); only this rail/detail layout stays TV-specific.
class TvSettingsScreen extends ConsumerStatefulWidget {
  const TvSettingsScreen({super.key});

  @override
  ConsumerState<TvSettingsScreen> createState() => _TvSettingsScreenState();
}

class _TvSettingsScreenState extends ConsumerState<TvSettingsScreen> {
  IptvSettingsSectionId _selected = IptvSettingsSectionId.theme;

  /// The sections this screen renders, in shared-manifest order, filtered to
  /// those declared visible on the TV shell.
  static final _sections = iptvSettingsSections
      .where((section) => section.isVisibleFor(ShellId.tv))
      .toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Row(
          children: [
            SizedBox(
              width: 260,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final section in _sections)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TvFocusable(
                        autofocus: section.id == IptvSettingsSectionId.theme,
                        onSelect: () =>
                            setState(() => _selected = section.id),
                        semanticLabel: section.labelFor(ShellId.tv),
                        semanticButton: true,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: section.id == _selected
                                ? colorScheme.primaryContainer
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Icon(
                                  section.iconFor(ShellId.tv),
                                  color: colorScheme.onSurface,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    section.labelFor(ShellId.tv),
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: colorScheme.onSurface,
                                    ),
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
            VerticalDivider(width: 1, color: colorScheme.outlineVariant),
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
      case IptvSettingsSectionId.theme:
        return const TvThemeSection(key: ValueKey('tv_settings_section_theme'));
      case IptvSettingsSectionId.playback:
        return const TvPlaybackSection(
          key: ValueKey('tv_settings_section_playback'),
        );
      case IptvSettingsSectionId.sources:
        return const TvSourceManagementSection(
          key: ValueKey('tv_settings_section_sources'),
        );
      case IptvSettingsSectionId.accessibility:
        return const _AccessibilityComingSoon();
      case IptvSettingsSectionId.playlistSource:
      case IptvSettingsSectionId.epgGuideSource:
      case IptvSettingsSectionId.country:
      case IptvSettingsSectionId.audio:
        // Not part of the TV rail today (`_sections` filters to sections
        // `isVisibleFor(ShellId.tv)`), so `_selected` can never actually
        // resolve here. Kept exhaustive since `IptvSettingsSectionId` is a
        // shared enum other shells also declare visibility for.
        return const SizedBox.shrink();
    }
  }
}

class _AccessibilityComingSoon extends StatelessWidget {
  const _AccessibilityComingSoon();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Accessibility',
            style: TextStyle(color: colorScheme.onSurface, fontSize: 20),
          ),
          const SizedBox(height: 8),
          Text(
            'Coming soon',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
