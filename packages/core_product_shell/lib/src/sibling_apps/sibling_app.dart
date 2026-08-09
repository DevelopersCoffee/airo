import 'package:flutter/foundation.dart' show immutable;

import '../shell_id.dart';

/// One entry in the cross-app promotion registry: everything a "More Airo
/// Apps" section needs to render a card for a sibling shipped app and route
/// the user to it.
///
/// [deepLinkScheme] is carried but unused today — v1 always opens the store
/// listing (see SPEC.md open question 1). It exists so a later phase can add
/// deep-linking without changing this shape.
@immutable
class SiblingApp {
  const SiblingApp({
    required this.id,
    required this.name,
    required this.pitch,
    required this.iconAsset,
    required this.androidStoreUrl,
    required this.iosStoreUrl,
    this.isPublishedAndroid = false,
    this.isPublishedIos = false,
    this.deepLinkScheme,
  });

  /// The shell this entry promotes.
  final ShellId id;

  /// Display name, e.g. "Airo TV".
  final String name;

  /// One-line pitch shown under the name.
  final String pitch;

  /// Asset path to this app's icon, shared across all shells' cards.
  final String iconAsset;

  final Uri androidStoreUrl;
  final Uri iosStoreUrl;

  /// Whether the Play Store / App Store listing is live. When false, the
  /// card renders a disabled "Coming soon" state instead of a store link.
  final bool isPublishedAndroid;
  final bool isPublishedIos;

  /// Reserved for future deep-link-if-installed support. Unused in v1.
  final String? deepLinkScheme;

  @override
  bool operator ==(Object other) => other is SiblingApp && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
