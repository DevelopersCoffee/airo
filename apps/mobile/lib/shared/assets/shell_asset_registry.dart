/// Central registry for shell-owned branding and shared chrome imagery.
///
/// Shell-level widgets should depend on these identifiers instead of embedding
/// raw asset paths in individual widgets.
abstract final class ShellAssetRegistry {
  static const String appIconRaster = 'assets/airo_icon.png';
  static const String appIconVector = 'assets/airo_icon.svg';
  static const String shellBackdrop = 'assets/hermes/images/filler-bg0.jpg';
}
