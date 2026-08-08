import 'package:core_product_shell/core_product_shell.dart';

/// Registers nothing. Airo Mind is absent from shared-surface builds.
///
/// **R05: Mind renders only on a device one person owns.** Web is a shared
/// surface — a browser tab is a screen other people sit in front of, borrow,
/// and screen-share. So Mind is absent from that binary rather than disabled
/// inside it: a runtime flag can be flipped, an unregistered module has no
/// routes to reach.
///
/// This is the `dart.library` half of the seam declared in `main.dart`
/// (`register_mind_module_web.dart if (dart.library.io)
/// register_mind_module_io.dart`), the same idiom the repo already uses for
/// Drift, the chess engine, and the money repositories. The web compile picks
/// this file, so the entrypoint's import graph never reaches
/// `package:feature_mind` or `AppAssistantHostAdapter` through the registry.
///
/// **This file must never import `package:feature_mind` and must never name
/// `MindModule`.** `scripts/check-mind-private-devices.sh` asserts exactly
/// that, with a positive control, and
/// `packages/feature_mind/test/rules/r05_private_devices_test.dart` mutates
/// this file to prove the gate can still fail.
void registerMindModule(ModuleRegistry registry) {
  // Intentionally empty. See the doc comment: absence is the mechanism.
}
