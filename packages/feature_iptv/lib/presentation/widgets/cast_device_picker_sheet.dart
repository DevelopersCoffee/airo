import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_player/platform_player.dart';

import '../../application/providers/iptv_cast_providers.dart';

Future<void> showIptvCastDevicePicker({
  required BuildContext context,
  required ValueChanged<AiroCastDevice> onDeviceSelected,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
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
      AiroCastDiscoveryPhase.discovering => const ListTile(
        leading: SizedBox(
          height: 24,
          width: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        title: Text('Searching for TVs...'),
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
        subtitle: const Text(
          'Make sure your phone and TV are on the same Wi-Fi.',
        ),
        trailing: TextButton(onPressed: onRetry, child: const Text('Refresh')),
      ),
      AiroCastDiscoveryPhase.failed => ListTile(
        leading: const Icon(Icons.error_outline),
        title: const Text('Cast discovery failed'),
        subtitle: Text(discovery.error ?? 'Try again.'),
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
