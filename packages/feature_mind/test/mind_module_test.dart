import 'package:core_product_shell/core_product_shell.dart';
import 'package:feature_mind/feature_mind.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderException;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/fake_assistant_host_adapter.dart';

MindModule _module({MindService Function()? createService}) => MindModule(
  hostAdapterBuilder: (ref) => FakeAssistantHostAdapter(),
  createService: createService,
);

Iterable<String> _namesOf(Iterable<RouteBase> routes) sync* {
  for (final route in routes) {
    if (route is GoRoute && route.name != null) yield route.name!;
    yield* _namesOf(route.routes);
  }
}

void main() {
  test('module ships on the super app and the standalone Mind shell', () {
    final module = _module();

    expect(module.id, 'mind');
    expect(module.supportedShells, {ShellId.mobile, ShellId.mind});
    expect(module.isEnabledForShell(ShellId.tv), isFalse);
  });

  test('hub routes carry every assistant destination', () {
    final hub = _module().hubRoutesFor(ShellId.mobile);

    expect(_namesOf(hub), [
      AssistantRouteNames.assistantName,
      AssistantRouteNames.chatName,
      AssistantRouteNames.notificationsName,
      AssistantRouteNames.profileName,
      AssistantRouteNames.modelsName,
      AssistantRouteNames.deviceCapabilitiesName,
      AssistantRouteNames.modelAdvisorName,
      AssistantRouteNames.promptLabName,
      AssistantRouteNames.audioScribeName,
      AssistantRouteNames.agentSkillsName,
      AssistantRouteNames.mobileActionsName,
      AssistantRouteNames.calendarName,
    ]);
  });

  test('wellbeing is a root destination on mobile, never a hub child', () {
    final module = _module();

    expect(_namesOf(module.rootRoutesFor(ShellId.mobile)), [
      AssistantRouteNames.wellbeingName,
    ]);
    expect(
      _namesOf(module.hubRoutesFor(ShellId.mobile)),
      isNot(contains(AssistantRouteNames.wellbeingName)),
    );
  });

  test('wellbeing is not a Mind-shell destination', () {
    final module = _module();

    expect(_namesOf(module.rootRoutesFor(ShellId.mind)), isEmpty);
  });

  test('routesFor concatenates hub, root, then scribe routes', () {
    final module = _module();

    expect(_namesOf(module.routesFor(ShellId.mobile)), [
      ..._namesOf(module.hubRoutesFor(ShellId.mobile)),
      ..._namesOf(module.rootRoutesFor(ShellId.mobile)),
      ..._namesOf(module.scribeRoutesFor(ShellId.mobile)),
    ]);
  });

  test('both shells mount the assistant hub at the same path', () {
    final module = _module();
    final mobile = module.hubRoutesFor(ShellId.mobile).first as GoRoute;
    final mind = module.hubRoutesFor(ShellId.mind).first as GoRoute;

    expect(mobile.path, AssistantRouteNames.assistant);
    expect(mind.path, mobile.path);
  });

  test('declared mount points match the paths the package navigates to', () {
    // The hub tiles, tool registry, and notification payloads all push
    // absolute `/assistant/...` locations, so the declared routes have to
    // resolve at exactly those paths — a rebased mount would 404 the
    // package's own navigation.
    final module = _module();
    final hub = module.hubRoutesFor(ShellId.mobile).first as GoRoute;

    String absolute(GoRoute child) => '${hub.path}/${child.path}';
    final childPaths = hub.routes.whereType<GoRoute>().map(absolute);

    expect(hub.path, AssistantRouteNames.assistant);
    expect(childPaths, [
      AssistantRouteNames.chat,
      AssistantRouteNames.notifications,
      AssistantRouteNames.profile,
      AssistantRouteNames.models,
      AssistantRouteNames.deviceCapabilities,
      AssistantRouteNames.modelAdvisor,
      AssistantRouteNames.promptLab,
      AssistantRouteNames.audioScribe,
      AssistantRouteNames.agentSkills,
      AssistantRouteNames.mobileActions,
      AssistantRouteNames.calendar,
    ]);
    expect(
      (module.rootRoutesFor(ShellId.mobile).first as GoRoute).path,
      AssistantRouteNames.wellbeing,
    );
  });

  test('module installs the host adapter its screens require', () {
    final adapter = FakeAssistantHostAdapter();
    final module = MindModule(hostAdapterBuilder: (ref) => adapter);
    final container = ProviderContainer(
      overrides: module.providerOverridesFor(ShellId.mobile),
    );
    addTearDown(container.dispose);

    expect(container.read(assistantHostAdapterProvider), same(adapter));
  });

  test('an unmounted assistant provider still fails loudly', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      () => container.read(assistantHostAdapterProvider),
      throwsA(
        isA<ProviderException>().having(
          (error) => error.exception,
          'exception',
          isUnimplementedError,
        ),
      ),
    );
  });

  test('a registry accepts the module without route conflicts', () {
    final registry = ModuleRegistry(shell: ShellId.mobile)..register(_module());

    expect(registry.moduleIds, ['mind']);
    expect(
      registry.routesForModule('mind').length,
      _module().routesFor(ShellId.mobile).length,
    );
  });

  group('scribe route', () {
    test('is absent when no createService is supplied', () {
      final module = _module();

      expect(module.scribeRoutesFor(ShellId.mind), isEmpty);
      expect(
        module.routesFor(ShellId.mind),
        isNot(contains(isA<GoRoute>().having((r) => r.path, 'path', '/'))),
      );
    });

    test('mounts at "/" when createService is supplied', () {
      final module = _module(createService: () => throw UnimplementedError());
      final scribe = module.scribeRoutesFor(ShellId.mind).single as GoRoute;

      expect(scribe.path, '/');
      expect(scribe.name, 'mind_scribe');
    });

    test('service factory is not called until service is read', () {
      var calls = 0;
      _module(
        createService: () {
          calls++;
          throw UnimplementedError();
        },
      );

      expect(calls, 0);
    });

    test('initialize is a no-op without createService', () async {
      final module = _module();
      await module.initialize();
      // No exception, and nothing to dispose.
      await module.dispose();
    });
  });
}
