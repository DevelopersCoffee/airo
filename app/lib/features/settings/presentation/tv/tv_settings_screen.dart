import 'package:core_product_shell/core_product_shell.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_ui/core_ui.dart';

import 'tv_theme_section.dart';

/// TV Settings screen (CV-022): a left-hand section list, right-hand detail
/// pane. `TvPlaybackSection` and `TvSourceManagementSection` are IPTV-module
/// concerns and live in `package:feature_iptv`; `TvThemeSection` stays here
/// because it shares the app-wide `appThemeProvider` with the phone profile
/// screen (a promoted, cross-app setting, not IPTV-local). Section
/// names/icons come from the shared `iptvSettingsSections` manifest (SSOT
/// with the mobile settings hub); only this rail/detail layout stays
/// TV-specific.
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
  late final Map<IptvSettingsSectionId, FocusNode> _sectionFocusNodes = {
    for (final section in _sections)
      section.id: FocusNode(debugLabel: 'TV settings ${section.id.name}'),
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _sectionFocusNodes[_selected]?.requestFocus();
      // Fire TV may restore the rail item that launched this overlay after
      // its first frame. Reassert the section target once that restoration
      // has completed so selected styling and actual D-pad focus cannot
      // diverge.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _sectionFocusNodes[_selected]?.requestFocus();
      });
    });
  }

  @override
  void dispose() {
    for (final node in _sectionFocusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

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
                        focusNode: _sectionFocusNodes[section.id],
                        autofocus: section.id == IptvSettingsSectionId.theme,
                        onSelect: () => setState(() => _selected = section.id),
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
        return ref.watch(tvSourceManagementSectionBuilderProvider)(
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
