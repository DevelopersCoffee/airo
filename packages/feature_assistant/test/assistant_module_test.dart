import 'package:core_product_shell/core_product_shell.dart';
import 'package:feature_assistant/feature_assistant.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderException;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/fake_assistant_host_adapter.dart';

AssistantModule _module({String basePath = AssistantRouteNames.assistant}) =>
    AssistantModule(
      hostAdapterBuilder: (ref) => FakeAssistantHostAdapter(),
      basePath: basePath,
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

    expect(module.id, 'assistant');
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
    ]);
  });

  test('wellbeing is a root destination, never a hub child', () {
    final module = _module();

    expect(_namesOf(module.rootRoutesFor(ShellId.mobile)), [
      AssistantRouteNames.wellbeingName,
    ]);
    expect(
      _namesOf(module.hubRoutesFor(ShellId.mobile)),
      isNot(contains(AssistantRouteNames.wellbeingName)),
    );
  });

  test('routesFor concatenates hub routes first, then root routes', () {
    final module = _module();

    expect(_namesOf(module.routesFor(ShellId.mobile)), [
      ..._namesOf(module.hubRoutesFor(ShellId.mobile)),
      ..._namesOf(module.rootRoutesFor(ShellId.mobile)),
    ]);
  });

  test('both shells mount the assistant hub at the same path', () {
    final module = _module();
    final mobile = module.hubRoutesFor(ShellId.mobile).first as GoRoute;
    final mind = module.hubRoutesFor(ShellId.mind).first as GoRoute;

    expect(mobile.path, AssistantRouteNames.assistant);
    expect(mind.path, mobile.path);
  });

  test('basePath rebases the hub and its child navigation', () {
    final module = _module(basePath: '/mind');
    final hub = module.hubRoutesFor(ShellId.mind).first as GoRoute;

    expect(hub.path, '/mind');
    // Children stay relative, so they inherit the rebased parent.
    expect(
      hub.routes.whereType<GoRoute>().map((route) => route.path),
      isNot(contains(startsWith('/'))),
    );
  });

  test('module installs the host adapter its screens require', () {
    final adapter = FakeAssistantHostAdapter();
    final module = AssistantModule(hostAdapterBuilder: (ref) => adapter);
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

    expect(registry.moduleIds, ['assistant']);
    expect(
      registry.routesForModule('assistant').length,
      _module().routesFor(ShellId.mobile).length,
    );
  });
}
