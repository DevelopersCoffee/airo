import '../shell_id.dart';
import 'sibling_app.dart';

/// Shared placeholder icon for every sibling-app card. No per-flavor icon
/// assets exist yet for Coins/Mind, and TV only has a banner (not an
/// icon) — cards distinguish apps by name/pitch text until real icons land,
/// at which point swap each entry's [SiblingApp.iconAsset] individually.
const _placeholderIconAsset =
    'packages/core_product_shell/assets/sibling_icons/airo_mark.png';

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
    iconAsset: _placeholderIconAsset,
    androidStoreUrl: _playStoreUrl('com.airo.app'),
    iosStoreUrl: _appStoreUrl('com.airo.app'),
  ),
  SiblingApp(
    id: ShellId.tv,
    name: 'Aika Stream',
    pitch: 'Bring your own authorized playlists to Android TV.',
    iconAsset: _placeholderIconAsset,
    androidStoreUrl: _playStoreUrl('com.developerscoffee.tv.midas'),
    iosStoreUrl: _appStoreUrl('com.airo.tv'),
  ),
  SiblingApp(
    id: ShellId.coins,
    name: 'Airo Coins',
    pitch: 'Track and manage your personal finances.',
    iconAsset: _placeholderIconAsset,
    androidStoreUrl: _playStoreUrl('com.airo.coins'),
    iosStoreUrl: _appStoreUrl('com.airo.coins'),
  ),
  SiblingApp(
    id: ShellId.mind,
    name: 'Airo Mind',
    pitch: 'A private, local-first AI assistant.',
    iconAsset: _placeholderIconAsset,
    androidStoreUrl: _playStoreUrl('com.airo.mind'),
    iosStoreUrl: _appStoreUrl('com.airo.mind'),
  ),
];

/// Returns every shipped app except [current]. Shells not present in
/// [siblingApps] (e.g. the qualification/patrol QA harness, which has no
/// settings screen of its own) simply get an empty list.
List<SiblingApp> siblingAppsFor(ShellId current) =>
    siblingApps.where((app) => app.id != current).toList(growable: false);

/// [siblingAppsFor], minus anything with no live listing yet.
///
/// Settings screens render their "More Airo Apps" section from this, so a
/// section where every card would be an inert "Coming soon" is not shown at
/// all. Today that is every entry — the `isPublished*` flags above are still
/// placeholders — so the section is hidden everywhere until a flag is
/// flipped, at which point it appears on its own with no other change.
List<SiblingApp> publishedSiblingAppsFor(ShellId current) => siblingAppsFor(
  current,
).where((app) => app.isPublishedAnywhere).toList(growable: false);

Uri _playStoreUrl(String packageId) =>
    Uri.parse('https://play.google.com/store/apps/details?id=$packageId');

Uri _appStoreUrl(String bundleId) =>
    Uri.parse('https://apps.apple.com/app/$bundleId');
