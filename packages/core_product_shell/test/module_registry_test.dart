import 'package:core_product_shell/core_product_shell.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeModule extends AppModule {
  _FakeModule({
    required this.id,
    required this.supportedShells,
    this.onInitialize,
  });

  @override
  final String id;

  @override
  final Set<ShellId> supportedShells;

  final void Function()? onInitialize;

  @override
  List<RouteBase> routesFor(ShellId shell) => [
    GoRoute(
      path: '/$id/${shell.value}',
      builder: (_, _) => throw UnimplementedError(),
    ),
  ];

  @override
  Future<void> initialize() async => onInitialize?.call();
}

class _ThrowingModule extends AppModule {
  @override
  String get id => 'throwing';

  @override
  Set<ShellId> get supportedShells => {ShellId.mobile, ShellId.tv, ShellId.coins};

  @override
  List<RouteBase> routesFor(ShellId shell) => const [];

  @override
  Future<void> initialize() async => throw StateError('boom');

  @override
  Future<void> dispose() async => throw StateError('boom-dispose');
}

void main() {
  group('ShellId', () {
    test('known shells are distinct and stable', () {
      expect(ShellId.mobile, ShellId.mobile);
      expect(ShellId.mobile == ShellId.tv, isFalse);
      expect(ShellId.mobile == ShellId.coins, isFalse);
      expect(ShellId.mobile.hashCode, const ShellId('mobile').hashCode);
    });

    test('an arbitrary (unanticipated) shell identifier works as data', () {
      const futureShell = ShellId('music');
      const sameShell = ShellId('music');
      expect(futureShell.value, 'music');
      expect(futureShell == sameShell, isTrue);
    });
  });

  group('ModuleRegistry', () {
    test('only registers modules enabled for its shell', () {
      final registry = ModuleRegistry(shell: ShellId.tv);
      final iptv = _FakeModule(
        id: 'iptv',
        supportedShells: {ShellId.mobile, ShellId.tv},
      );
      final mobileOnly = _FakeModule(
        id: 'music',
        supportedShells: {ShellId.mobile},
      );

      registry.register(iptv);
      registry.register(mobileOnly);

      expect(registry.isRegistered('iptv'), isTrue);
      expect(registry.isRegistered('music'), isFalse);
      expect(registry.moduleCount, 1);
      expect(registry.moduleIds, ['iptv']);
    });

    test('resolves routes and overrides scoped to its shell', () {
      final registry = ModuleRegistry(shell: ShellId.mobile);
      registry.register(
        _FakeModule(id: 'iptv', supportedShells: {ShellId.mobile, ShellId.tv}),
      );

      final routes = registry.allRoutes;
      expect(routes, hasLength(1));
      expect((routes.single as GoRoute).path, '/iptv/mobile');
      expect(registry.allProviderOverrides, isEmpty);
    });

    test(
      'a third shell identifier (e.g. Airo Coins) works with no code branch '
      'changes required',
      () {
        final registry = ModuleRegistry(shell: ShellId.coins);
        registry.register(
          _FakeModule(
            id: 'iptv',
            supportedShells: {ShellId.mobile, ShellId.tv},
          ),
        );
        registry.register(
          _FakeModule(
            id: 'coins-ledger',
            supportedShells: {ShellId.coins},
          ),
        );

        expect(registry.moduleIds, ['coins-ledger']);
        expect(
          (registry.allRoutes.single as GoRoute).path,
          '/coins-ledger/coins',
        );
      },
    );

    test('initializeAll runs each module once and is idempotent', () async {
      final registry = ModuleRegistry(shell: ShellId.mobile);
      var initCount = 0;
      registry.register(
        _FakeModule(
          id: 'iptv',
          supportedShells: {ShellId.mobile},
          onInitialize: () => initCount++,
        ),
      );

      await registry.initializeAll();
      await registry.initializeAll();

      expect(initCount, 1);
    });

    test('a failing module.initialize reports via onError without aborting '
        'the rest', () async {
      final registry = ModuleRegistry(shell: ShellId.mobile);
      var otherInitialized = false;
      registry.register(_ThrowingModule());
      registry.register(
        _FakeModule(
          id: 'ok',
          supportedShells: {ShellId.mobile},
          onInitialize: () => otherInitialized = true,
        ),
      );

      Object? reportedError;
      await registry.initializeAll(
        onError: (error, module) => reportedError = error,
      );

      expect(otherInitialized, isTrue);
      expect(reportedError, isA<StateError>());
    });

    test('disposeAll clears the registry and reports dispose errors', () async {
      final registry = ModuleRegistry(shell: ShellId.mobile);
      registry.register(_ThrowingModule());

      Object? reportedError;
      await registry.disposeAll(
        onError: (error, module) => reportedError = error,
      );

      expect(registry.moduleCount, 0);
      expect(reportedError, isA<StateError>());
    });
  });

  group('Override export sanity', () {
    test('providerOverridesFor default is empty', () {
      final module = _FakeModule(id: 'x', supportedShells: {ShellId.mobile});
      expect(module.providerOverridesFor(ShellId.mobile), isA<List<Override>>());
      expect(module.providerOverridesFor(ShellId.mobile), isEmpty);
    });
  });
}
