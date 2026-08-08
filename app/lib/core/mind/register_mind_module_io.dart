import 'package:core_product_shell/core_product_shell.dart';
import 'package:feature_mind/feature_mind.dart';

import '../assistant/app_assistant_host_adapter.dart';

/// Registers Airo Mind on the private-device builds (Android, iOS, desktop).
///
/// The `dart.library.io` half of the seam declared in `main.dart`. Everything
/// `feature_mind`-typed that the super app's registry needs lives here rather
/// than in the entrypoint, so the web compile — which resolves the seam to
/// `register_mind_module_web.dart` — never reaches it. See that file for the
/// R05 reasoning.
///
/// The arguments are the ones the entrypoint passed inline before the move:
/// the module owns installing its own host seam, so registering it is the
/// whole wiring.
void registerMindModule(ModuleRegistry registry) {
  registry.register(
    MindModule(hostAdapterBuilder: AppAssistantHostAdapter.new),
  );
}
