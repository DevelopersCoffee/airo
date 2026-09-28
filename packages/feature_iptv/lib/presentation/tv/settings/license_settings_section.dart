import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Builds the license / plan block shown in Settings.
typedef LicenseSettingsSectionBuilder = Widget Function({Key? key});

/// Play / open-source default: disclosure only, no purchase or restore.
class FreeLicenseSettingsSection extends StatelessWidget {
  const FreeLicenseSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return const ListTile(
      leading: Icon(Icons.verified_outlined),
      title: Text('License'),
      subtitle: Text(
        'Free / Open Source\nPro features are not included in this build.',
      ),
      isThreeLine: true,
    );
  }
}

/// Overlay replaces this with the RevenueCat paywall. Play stays on
/// [FreeLicenseSettingsSection].
final licenseSettingsSectionBuilderProvider =
    Provider<LicenseSettingsSectionBuilder>(
      (ref) =>
          ({Key? key}) => FreeLicenseSettingsSection(key: key),
    );
