import 'package:airo_app/core/routing/app_router.dart';
import 'package:airo_app/main.dart';
import 'package:core_product_shell/core_product_shell.dart';
import 'package:feature_coin/feature_coin.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:airo_app/features/iptv/iptv_feature_module.dart';

/// The Mind tab's route names, exactly as the super app declared them inline
/// before `feature_assistant` was extracted. Deep links, notification
/// payloads, and `goNamed` call sites resolve on these, so the extraction is
/// only correct if every one of them still resolves — and to the same
/// location.
const _preExtractionAssistantRoutes = <String, String>{
  'Assistant': '/assistant',
  'assistant_chat': '/assistant/chat',
  'agent_notifications': '/assistant/notifications',
  'profile': '/assistant/profile',
  'assistant_models': '/assistant/models',
  'assistant_device_capabilities': '/assistant/device-capabilities',
  'assistant_model_advisor': '/assistant/model-advisor',
  'assistant_prompt_lab': '/assistant/prompt-lab',
  'assistant_audio_scribe': '/assistant/audio-scribe',
  'assistant_agent_skills': '/assistant/skills',
  'assistant_mobile_actions': '/assistant/mobile-actions',
  'Wellbeing': '/wellbeing',
};

void main() {
  test('every assistant route survives the feature_assistant extraction', () {
    final router = AppRouter.createRouter(
      moduleRegistry: buildMainModuleRegistry(),
    );
    addTearDown(router.dispose);

    for (final entry in _preExtractionAssistantRoutes.entries) {
      expect(
        router.namedLocation(entry.key),
        entry.value,
        reason:
            'route "${entry.key}" must still resolve to ${entry.value} after '
            'the feature_assistant extraction',
      );
    }
  });

  test('wellbeing stays outside the Mind navigation branch', () {
    final registry = buildMainModuleRegistry();
    final router = AppRouter.createRouter(moduleRegistry: registry);
    addTearDown(router.dispose);

    // Mounting Wellbeing inside the branch would keep the location working
    // while silently wrapping a full-screen destination in the bottom nav, so
    // assert on the mount point rather than only on the name.
    final branchPaths = router.configuration.routes
        .whereType<StatefulShellRoute>()
        .expand((shell) => shell.branches)
        .expand((branch) => branch.routes)
        .whereType<GoRoute>()
        .map((route) => route.path);

    expect(branchPaths, contains('/assistant'));
    expect(branchPaths, isNot(contains('/wellbeing')));
    expect(
      router.configuration.routes.whereType<GoRoute>().map(
        (route) => route.path,
      ),
      contains('/wellbeing'),
    );
  });

  test('the router refuses to start without the assistant module', () {
    final registry = ModuleRegistry(shell: ShellId.mobile)
      ..register(CoinVaultModule())
      ..register(IptvFeatureModule());

    expect(
      () => AppRouter.createRouter(moduleRegistry: registry),
      throwsA(
        isA<ModuleCompositionException>().having(
          (error) => error.message,
          'message',
          contains('assistant'),
        ),
      ),
    );
  });
}
