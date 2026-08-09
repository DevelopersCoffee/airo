/// Shared, shell-count-agnostic contract for app-shell module composition.
///
/// See ADR-0011 (`docs/adr/0011-super-app-modular-shell-ssot.md`) and
/// `tasks/ssot_airo_airo_tv_architecture_blueprint.md` for the target
/// architecture this package is phase 1 of.
library;

export 'src/app_module.dart';
export 'src/module_registry.dart';
export 'src/shell_id.dart';
export 'src/sibling_apps/sibling_app.dart';
export 'src/sibling_apps/sibling_app_registry.dart';
