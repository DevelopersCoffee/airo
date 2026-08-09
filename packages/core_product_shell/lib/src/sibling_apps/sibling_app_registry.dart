import '../shell_id.dart';
import 'sibling_app.dart';

/// SSOT for cross-app promotion: the four shipped Airo shells, each with
/// its store links. Every settings screen across every flavor renders its
/// "More Airo Apps" section from [siblingAppsFor] instead of hardcoding its
/// own copy — see SPEC.md.
///
/// Store URLs and `isPublished*` flags are placeholders pending confirmed
/// listing status (SPEC.md resolved decision 3) — flip the flag when a
/// listing goes live, no other code changes needed.
final siblingApps = <SiblingApp>[
  SiblingApp(
    id: ShellId.mobile,
    name: 'Airo',
    pitch: 'AI chat, finance, music, games, and reading in one app.',
    iconAsset: 'packages/core_product_shell/assets/sibling_icons/airo.png',
    androidStoreUrl: _playStoreUrl('com.airo.app'),
    iosStoreUrl: _appStoreUrl('com.airo.app'),
  ),
  SiblingApp(
    id: ShellId.tv,
    name: 'Airo TV',
    pitch: 'Live TV and IPTV built for the big screen.',
    iconAsset: 'packages/core_product_shell/assets/sibling_icons/airo_tv.png',
    androidStoreUrl: _playStoreUrl('com.airo.tv'),
    iosStoreUrl: _appStoreUrl('com.airo.tv'),
  ),
  SiblingApp(
    id: ShellId.coins,
    name: 'Airo Coins',
    pitch: 'Track and manage your personal finances.',
    iconAsset:
        'packages/core_product_shell/assets/sibling_icons/airo_coins.png',
    androidStoreUrl: _playStoreUrl('com.airo.coins'),
    iosStoreUrl: _appStoreUrl('com.airo.coins'),
  ),
  SiblingApp(
    id: ShellId.mind,
    name: 'Airo Mind',
    pitch: 'A private, local-first AI assistant.',
    iconAsset:
        'packages/core_product_shell/assets/sibling_icons/airo_mind.png',
    androidStoreUrl: _playStoreUrl('com.airo.mind'),
    iosStoreUrl: _appStoreUrl('com.airo.mind'),
  ),
];

/// Returns every shipped app except [current]. Shells not present in
/// [siblingApps] (e.g. the qualification/patrol QA harness, which has no
/// settings screen of its own) simply get an empty list.
List<SiblingApp> siblingAppsFor(ShellId current) =>
    siblingApps.where((app) => app.id != current).toList(growable: false);

Uri _playStoreUrl(String packageId) =>
    Uri.parse('https://play.google.com/store/apps/details?id=$packageId');

Uri _appStoreUrl(String bundleId) =>
    Uri.parse('https://apps.apple.com/app/$bundleId');
