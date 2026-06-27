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
}
