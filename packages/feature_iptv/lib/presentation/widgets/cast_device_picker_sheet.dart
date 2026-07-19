import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_player/platform_player.dart';

import '../../application/providers/iptv_cast_providers.dart';
import 'adaptive_iptv_sheet.dart';

const _castDiscoveryTroubleshootingGuidance =
    'Make sure the TV is awake and Cast is enabled, both devices are on the '
    'same Wi-Fi, and router client isolation is off.\n\n'
    'VPN may be blocking discovery. If the TV or Android/Fire TV uses a VPN, '
    'enable split tunneling/bypass for the TV player/Cast app or temporarily '
    'turn off the TV VPN.';

Future<void> showIptvCastDevicePicker({
  required BuildContext context,
  required ValueChanged<AiroCastDevice> onDeviceSelected,
}) {
  return showAdaptiveIptvSheet<void>(
    context: context,
    builder: (_) => CastDevicePickerSheet(onDeviceSelected: onDeviceSelected),
  );
}

class CastDevicePickerSheet extends ConsumerStatefulWidget {
  const CastDevicePickerSheet({super.key, required this.onDeviceSelected});

  final ValueChanged<AiroCastDevice> onDeviceSelected;

  @override
  ConsumerState<CastDevicePickerSheet> createState() =>
      _CastDevicePickerSheetState();
}

class _CastDevicePickerSheetState extends ConsumerState<CastDevicePickerSheet> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      ref.read(iptvCastProvider.notifier).startDiscovery();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(iptvCastProvider);
    final discovery = state.discovery;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cast to a device',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            const Text(
              'Choose one Chromecast-enabled TV on this Wi-Fi network.',
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            _DiscoveryBody(
              discovery: discovery,
              onRetry: () =>
                  ref.read(iptvCastProvider.notifier).startDiscovery(),
              onDeviceSelected: (device) {
                widget.onDeviceSelected(device);
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscoveryBody extends StatelessWidget {
  const _DiscoveryBody({
    required this.discovery,
    required this.onRetry,
    required this.onDeviceSelected,
  });

  final AiroCastDiscoveryState discovery;
  final VoidCallback onRetry;
  final ValueChanged<AiroCastDevice> onDeviceSelected;

  @override
  Widget build(BuildContext context) {
    return switch (discovery.phase) {
      AiroCastDiscoveryPhase.discovering => ListTile(
        leading: const SizedBox(
          height: 24,
          width: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        title: Text(AiroVoice.searching.pick()),
      ),
      AiroCastDiscoveryPhase.permissionRequired => ListTile(
        leading: const Icon(Icons.wifi_tethering_error),
        title: const Text('Local network permission needed'),
        subtitle: const Text(
          'Allow local network access so Airo can find Chromecast-enabled TVs.',
        ),
        trailing: TextButton(onPressed: onRetry, child: const Text('Retry')),
      ),
      AiroCastDiscoveryPhase.noDevices => ListTile(
        leading: const Icon(Icons.cast),
        title: const Text('No Cast devices found'),
        subtitle: const Text(_castDiscoveryTroubleshootingGuidance),
        trailing: TextButton(
          onPressed: onRetry,
          child: const Text('Scan again'),
        ),
      ),
      AiroCastDiscoveryPhase.failed => ListTile(
        leading: const Icon(Icons.error_outline),
        title: const Text('Cast discovery failed'),
        subtitle: Text(_failedDiscoveryMessage(discovery.error)),
        trailing: TextButton(onPressed: onRetry, child: const Text('Retry')),
      ),
      AiroCastDiscoveryPhase.found => Column(
        mainAxisSize: MainAxisSize.min,
        children: discovery.devices
            .map(
              (device) => ListTile(
                leading: const Icon(Icons.cast),
                title: Text(device.name),
                subtitle: Text(device.modelName ?? 'Google Cast receiver'),
                onTap: () => onDeviceSelected(device),
              ),
            )
            .toList(growable: false),
      ),
      AiroCastDiscoveryPhase.idle => ListTile(
        leading: const Icon(Icons.cast),
        title: const Text('Ready to search'),
        trailing: TextButton(onPressed: onRetry, child: const Text('Search')),
      ),
    };
  }
}

String _failedDiscoveryMessage(String? error) {
  final failure = error ?? 'Try again.';
  if (_errorExplainsPermissionOrPlatformUnavailability(failure)) {
    return failure;
  }

  return '$failure\n\n$_castDiscoveryTroubleshootingGuidance';
}

bool _errorExplainsPermissionOrPlatformUnavailability(String error) {
  final normalized = error.toLowerCase();
  return normalized.contains('permission') ||
      normalized.contains('local network access') ||
      normalized.contains('platform unavailable') ||
      normalized.contains('not available on this platform') ||
      normalized.contains('not supported on this platform');
}
