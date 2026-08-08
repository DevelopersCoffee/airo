import 'package:core_product_shell/core_product_shell.dart';
import 'package:feature_mind/feature_mind.dart';

import '../assistant/app_assistant_host_adapter.dart';

/// Registers Airo Mind into [registry]. Phone/desktop only.
///
/// `main.dart` imports this conditionally
/// (`if (dart.library.html) 'mind_registration_stub.dart'`) so a web build
/// never contains a `MindModule(` construction -- R05 requires a
/// shared-surface build to be unable to reach the module, not merely refrain
/// from calling it at runtime. See
/// `packages/feature_mind/lib/src/mind_availability.dart` and
/// `scripts/check-mind-private-devices.sh`.
void registerMind(ModuleRegistry registry) {
  registry.register(
    MindModule(hostAdapterBuilder: AppAssistantHostAdapter.new),
  );
}
