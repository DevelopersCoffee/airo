import 'dart:io';

import 'package:core_product_shell/core_product_shell.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Injectable in place of the real `launchUrl` so widget tests don't hit a
/// platform channel — mirrors the pattern used by `ModelDetailScreen`.
typedef LaunchSiblingAppUrl = Future<bool> Function(Uri url, {LaunchMode mode});

/// One card in a settings hub's "More Airo Apps" section: icon, name,
/// pitch, and a CTA that opens the platform-appropriate store listing, or
/// a disabled "Coming soon" state when [SiblingApp.isPublishedAndroid] /
/// [SiblingApp.isPublishedIos] says the listing isn't live yet.
class SiblingAppCard extends StatelessWidget {
  const SiblingAppCard({super.key, required this.app, this.launchUrlCallback});

  final SiblingApp app;
  final LaunchSiblingAppUrl? launchUrlCallback;

  bool get _isPublished =>
      Platform.isIOS ? app.isPublishedIos : app.isPublishedAndroid;

  Uri get _storeUrl => Platform.isIOS ? app.iosStoreUrl : app.androidStoreUrl;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Image.asset(app.iconAsset, width: 40, height: 40),
      title: Text(app.name),
      subtitle: Text(app.pitch),
      trailing: _isPublished
          ? const Icon(Icons.arrow_forward_ios, size: 16)
          : const Text('Coming soon'),
      enabled: _isPublished,
      onTap: _isPublished ? () => _open() : null,
    );
  }

  Future<void> _open() async {
    final launch = launchUrlCallback ?? launchUrl;
    await launch(_storeUrl, mode: LaunchMode.externalApplication);
  }
}
