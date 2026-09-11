import 'dart:io';

import 'package:airo_app/main_anya.dart';
import 'package:core_product_shell/core_product_shell.dart';
import 'package:feature_anya/feature_anya.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  test('Anya Android manifest removes the base MainActivity launcher', () {
    final manifest = File(
      'android/app/src/anya/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('xmlns:tools='));
    expect(
      manifest,
      contains(
        RegExp(r'android:name="\.MainActivity"[\s\S]*?tools:node="remove"'),
      ),
    );
    expect(manifest, contains('android:name=".AnyaActivity"'));
  });

  test('anya registry registers the anya module for ShellId.anya', () {
    final registry = buildAnyaModuleRegistry();

    expect(registry.shell, ShellId.anya);
    expect(registry.moduleIds, ['anya']);
    final paths = registry.allRoutes.whereType<GoRoute>().map((r) => r.path);
    expect(paths, contains('/'));
  });
}
