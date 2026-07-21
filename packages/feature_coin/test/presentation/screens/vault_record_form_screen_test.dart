// ignore_for_file: depend_on_referenced_packages

import 'dart:async';

import 'package:core_data/core_data.dart';
import 'package:core_domain/core_domain.dart';
import 'package:feature_coin/feature_coin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_coin_vault/platform_coin_vault.dart';

class _PendingKeyManager extends VaultKeyManager {
  _PendingKeyManager({required this.keyCompleter})
    : super.forTesting(
        secureStorage: InMemorySecureStorage(),
        authenticate: () async => true,
      );

  final Completer<Result<List<int>>> keyCompleter;

  @override
  Future<bool> isEncryptionAvailable() async => true;

  @override
  Future<Result<List<int>>> getDatabaseKey() => keyCompleter.future;
}

void main() {
  testWidgets(
    'direct add route stays locked until biometric unlock completes',
    (tester) async {
      final keyCompleter = Completer<Result<List<int>>>();
      final container = ProviderContainer(
        overrides: [
          vaultKeyManagerProvider.overrideWithValue(
            _PendingKeyManager(keyCompleter: keyCompleter),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: VaultRecordFormScreen(recordType: VaultRecordType.creditCard),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Vault locked'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Nickname *'), findsNothing);

      keyCompleter.complete(Success(List<int>.generate(32, (index) => index)));
      await tester.pumpAndSettle();

      expect(find.text('Vault locked'), findsNothing);
      expect(find.widgetWithText(TextFormField, 'Nickname *'), findsOneWidget);
      container.read(vaultSessionProvider.notifier).lock();
    },
  );
}
