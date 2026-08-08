import 'package:airo_app/core/app/main_provider_overrides.dart';
import 'package:airo_app/core/providers/navigation_provider.dart';
import 'package:airo_app/core/routing/app_router.dart';
import 'package:airo_app/main.dart';
import 'package:core_product_shell/core_product_shell.dart';
import 'package:feature_coin/feature_coin.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:airo_app/features/iptv/iptv_feature_module.dart';

/// What the phone bottom nav does on a build that composed no Mind module.
///
/// R05 takes Mind out of shared-surface builds by never registering it. The
/// router keeps the Mind *branch* so `navigationShell.currentIndex` stays
/// aligned with `AppNavigationTab.values`, and points it at a redirect. That
/// leaves one loose end this suite exists to pin down: the bottom nav is
/// built from `AppNavigationTab`, not from the registry, so without help it
/// still advertises an Assistant destination that only bounces the user to
/// Coins. A tab that silently does the wrong thing is worse than no tab.
void main() {
  ModuleRegistry mindlessRegistry() => ModuleRegistry(shell: ShellId.mobile)
    ..register(CoinVaultModule())
    ..register(IptvFeatureModule());

  Future<void> pumpShell(
    WidgetTester tester, {
    required List<Override> extraOverrides,
  }) async {
    SharedPreferences.setMockInitialValues({'is_logged_in': true});
    final prefs = await SharedPreferences.getInstance();
    final router = AppRouter.createRouter(
      moduleRegistry: mindlessRegistry(),
      initialLocation: '/money',
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          ...extraOverrides,
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('the nav policy alone would advertise a dead Assistant tab', (
    tester,
  ) async {
    // Characterization, not an endorsement: this is what the shell does when
    // nothing tells it Mind is absent. It is the reason the override below
    // exists, and it fails loudly if someone makes the policy Mind-aware by
    // some other route and forgets to delete this.
    await pumpShell(tester, extraOverrides: const []);

    expect(find.byKey(const ValueKey('app_nav_assistant')), findsOneWidget);
  });

  testWidgets('a build without Mind shows no Assistant destination', (
    tester,
  ) async {
    await pumpShell(
      tester,
      extraOverrides: [
        appNavigationPolicyProvider.overrideWithValue(
          appNavigationPolicy.without(AppNavigationTab.assistant),
        ),
      ],
    );

    expect(find.byKey(const ValueKey('app_nav_assistant')), findsNothing);
    // The other destinations are untouched — this removes one entry, it does
    // not rebuild the information architecture.
    expect(find.byKey(const ValueKey('app_nav_coins')), findsOneWidget);
    expect(find.byKey(const ValueKey('app_nav_beats')), findsOneWidget);
    expect(find.byKey(const ValueKey('app_nav_live')), findsOneWidget);
  });

  test('the tab drops exactly when Mind is absent, not when web', () async {
    // Asserted where the decision is made: keyed on the composed registry
    // rather than on `kIsWeb`, so chrome and composition cannot disagree —
    // and so a private-device build keeps the tab byte-identically.
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    bool showsAssistant(ModuleRegistry registry) {
      final container = ProviderContainer(
        overrides: buildMainProviderOverrides(
          prefs: prefs,
          epgReminderGateway: const UnavailableEpgReminderNotificationGateway(),
          moduleRegistry: registry,
        ),
      );
      addTearDown(container.dispose);
      return container
          .read(appNavigationPolicyProvider)
          .widePrimaryTabs
          .contains(AppNavigationTab.assistant);
    }

    expect(showsAssistant(mindlessRegistry()), isFalse);
    expect(showsAssistant(buildMainModuleRegistry()), isTrue);
  });
}
