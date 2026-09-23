import 'package:core_product_shell/core_product_shell.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('iptvSettingsSections', () {
    List<IptvSettingsSectionDescriptor> visibleOn(ShellId shell) =>
        iptvSettingsSections.where((s) => s.isVisibleFor(shell)).toList();

    test('mobile sees theme, accessibility, playback, playlistSource, '
        'epgGuideSource, country, audio — and not privacy', () {
      expect(visibleOn(ShellId.mobile).map((s) => s.id).toSet(), {
        IptvSettingsSectionId.theme,
        IptvSettingsSectionId.accessibility,
        IptvSettingsSectionId.playback,
        IptvSettingsSectionId.playlistSource,
        IptvSettingsSectionId.epgGuideSource,
        IptvSettingsSectionId.country,
        IptvSettingsSectionId.audio,
      });
      expect(
        visibleOn(ShellId.mobile).map((s) => s.id),
        isNot(contains(IptvSettingsSectionId.privacy)),
      );
    });

    test('TV visible order is Theme, Accessibility, Playback, Country, '
        'Sources, Privacy', () {
      expect(visibleOn(ShellId.tv).map((s) => s.id).toList(), const [
        IptvSettingsSectionId.theme,
        IptvSettingsSectionId.accessibility,
        IptvSettingsSectionId.playback,
        IptvSettingsSectionId.country,
        IptvSettingsSectionId.sources,
        IptvSettingsSectionId.privacy,
      ]);
    });

    test('accessibility has no redundant TV label override', () {
      final accessibility = iptvSettingsSections.firstWhere(
        (s) => s.id == IptvSettingsSectionId.accessibility,
      );
      expect(accessibility.labelFor(ShellId.tv), 'Accessibility');
      expect(accessibility.labelFor(ShellId.mobile), 'Accessibility');
      expect(accessibility.shellLabelOverrides, isEmpty);
    });

    test('theme section renders as "Appearance" on mobile and "Theme" on '
        'TV', () {
      final theme = iptvSettingsSections.firstWhere(
        (s) => s.id == IptvSettingsSectionId.theme,
      );

      expect(theme.labelFor(ShellId.mobile), 'Appearance');
      expect(theme.labelFor(ShellId.tv), 'Theme');
    });

    test('playback section keeps its distinct existing icon per shell', () {
      final playback = iptvSettingsSections.firstWhere(
        (s) => s.id == IptvSettingsSectionId.playback,
      );

      expect(
        playback.iconFor(ShellId.mobile).codePoint,
        isNot(playback.icon.codePoint),
      );
      expect(playback.iconFor(ShellId.tv).codePoint, playback.icon.codePoint);
    });

    test(
      'an unregistered third shell (Airo Coins) sees no IPTV settings '
      'sections yet, without requiring any branch changes to this manifest',
      () {
        expect(visibleOn(ShellId.coins), isEmpty);
      },
    );
  });
}
