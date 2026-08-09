import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Settings-hub row showing this build's version and build number, e.g.
/// "2.4.1 (318)". Tapping expands to show the package name too — useful
/// when a user is reporting a bug and support needs to know exactly which
/// build they're on.
///
/// [loadPackageInfo] defaults to the real platform channel but is
/// overridable so widget tests don't depend on it.
class AppInfoTile extends StatefulWidget {
  const AppInfoTile({
    super.key,
    this.loadPackageInfo = PackageInfo.fromPlatform,
  });

  final Future<PackageInfo> Function() loadPackageInfo;

  @override
  State<AppInfoTile> createState() => _AppInfoTileState();
}

class _AppInfoTileState extends State<AppInfoTile> {
  PackageInfo? _info;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    widget.loadPackageInfo().then((info) {
      if (mounted) setState(() => _info = info);
    });
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    if (info == null) return const SizedBox.shrink();

    return ListTile(
      leading: const Icon(Icons.info_outline),
      title: const Text('App version'),
      subtitle: Text(
        _expanded
            ? '${info.version} (${info.buildNumber}) · ${info.packageName}'
            : '${info.version} (${info.buildNumber})',
      ),
      onTap: () => setState(() => _expanded = !_expanded),
    );
  }
}
