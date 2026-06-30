import 'dart:io';

import 'package:airo_app/shared/assets/shell_asset_registry.dart';
import 'package:airo_app/shared/widgets/app_icon_placeholder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shell asset registry exposes shell-owned branding assets', () {
    expect(ShellAssetRegistry.appIconRaster, 'assets/airo_icon.png');
    expect(ShellAssetRegistry.appIconVector, 'assets/airo_icon.svg');
    expect(
      ShellAssetRegistry.shellBackdrop,
      'assets/hermes/images/filler-bg0.jpg',
    );
  });

  test('app icon placeholder consumes the shared shell asset registry', () {
    expect(AppIconPlaceholder.assetPath, ShellAssetRegistry.appIconRaster);
  });

  test('shell backdrop path is not hardcoded in feature sources', () async {
    final libDir = Directory('lib');
    final offenders = <String>[];

    await for (final entity in libDir.list(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) {
        continue;
      }
      if (entity.path.endsWith('shared/assets/shell_asset_registry.dart')) {
        continue;
      }

      final contents = await entity.readAsString();
      if (contents.contains('assets/hermes/images/filler-bg0.jpg')) {
        offenders.add(entity.path);
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Remaining hardcoded shell backdrop references must migrate to ShellAssetRegistry.',
    );
  });
}
