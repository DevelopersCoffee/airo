import 'package:feature_coins_core/feature_coins_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/providers/coins_currency_provider.dart';

/// Local device settings for the Airo Coins shell.
class CoinsSettingsScreen extends ConsumerWidget {
  const CoinsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency = ref.watch(coinsCurrencyProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Coins settings')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Currency'),
            subtitle: Text(_labelForCode(currency.currencyCode)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _pickCurrency(context, ref),
          ),
          if (!currency.userSelected)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Using a smart default from your device locale or timezone '
                'until you choose a currency.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }

  String _labelForCode(String code) {
    for (final entry in CurrencyCode.values) {
      if (entry.code == code) {
        return '${entry.name} (${entry.symbol})';
      }
    }
    return code;
  }

  Future<void> _pickCurrency(BuildContext context, WidgetRef ref) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Choose a currency',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              for (final entry in CurrencyCode.values)
                ListTile(
                  title: Text('${entry.name} (${entry.symbol})'),
                  subtitle: Text(entry.code),
                  onTap: () => Navigator.of(context).pop(entry.code),
                ),
            ],
          ),
        );
      },
    );
    if (selected == null) return;
    await ref.read(coinsCurrencyProvider.notifier).setCurrencyCode(selected);
  }
}
