import 'package:core_product_shell/core_product_shell.dart';

/// Web's counterpart to `mind_registration.dart`: does not link
/// `feature_mind`, so nothing registers under module id `'mind'`.
///
/// `AppRouter.createRouter` treats a missing `'mind'` module as absent rather
/// than a startup failure -- see `_optionalModule` in `app_router.dart`.
void registerMind(ModuleRegistry registry) {}
