import 'package:core_entitlements/core_entitlements.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeModule implements ProModule {
  _FakeModule(this.id, this.feature, {this.failOnInit = false});

  @override
  final String id;

  @override
  final ProFeature feature;

  final bool failOnInit;
  bool initialized = false;

  @override
  Future<void> initialize() async {
    if (failOnInit) throw StateError('boom');
    initialized = true;
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  group('LaunchPromoEntitlements', () {
    test('enables every feature', () {
      const entitlements = LaunchPromoEntitlements();
      for (final feature in ProFeature.values) {
        expect(entitlements.isEnabled(feature), isTrue);
      }
    });

    test('emits the full feature set', () async {
      final set = await const LaunchPromoEntitlements().changes.first;
      expect(set, ProFeature.values.toSet());
    });
  });

  group('NoEntitlements', () {
    test('denies every feature', () {
      const entitlements = NoEntitlements();
      for (final feature in ProFeature.values) {
        expect(entitlements.isEnabled(feature), isFalse);
      }
    });
  });

  group('ProFeature', () {
    test('stable ids are unique', () {
      final ids = ProFeature.values.map((f) => f.stableId).toSet();
      expect(ids.length, ProFeature.values.length);
    });
  });

  group('ProModuleRegistry', () {
    test('initializes only entitled modules', () async {
      final registry = ProModuleRegistry(const LaunchPromoEntitlements());
      final module = _FakeModule('m1', ProFeature.importIntelligence);
      registry.register(module);

      final initialized = await registry.initializeEntitled();

      expect(initialized, ['m1']);
      expect(module.initialized, isTrue);
    });

    test('skips modules when nothing is entitled', () async {
      final registry = ProModuleRegistry(const NoEntitlements());
      final module = _FakeModule('m1', ProFeature.importIntelligence);
      registry.register(module);

      final initialized = await registry.initializeEntitled();

      expect(initialized, isEmpty);
      expect(module.initialized, isFalse);
    });

    test('rejects duplicate module ids', () {
      final registry = ProModuleRegistry(const LaunchPromoEntitlements())
        ..register(_FakeModule('m1', ProFeature.epgReminders));

      expect(
        () => registry.register(_FakeModule('m1', ProFeature.sportsDesk)),
        throwsStateError,
      );
    });

    test('contains per-module init failures', () async {
      final registry = ProModuleRegistry(const LaunchPromoEntitlements());
      final broken = _FakeModule(
        'broken',
        ProFeature.sportsDesk,
        failOnInit: true,
      );
      final healthy = _FakeModule('healthy', ProFeature.epgReminders);
      registry
        ..register(broken)
        ..register(healthy);

      final initialized = await registry.initializeEntitled();

      expect(initialized, ['healthy']);
      expect(healthy.initialized, isTrue);
    });
  });
}
