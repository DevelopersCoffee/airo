import 'package:airo_app/core/pro/pro_bootstrap_runner.dart';
import 'package:core_entitlements/core_entitlements.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingModule implements ProModule {
  _RecordingModule(this.id, this.feature, {this.throwOnInit = false});

  @override
  final String id;
  @override
  final ProFeature feature;
  final bool throwOnInit;

  var initialized = 0;
  var disposed = 0;

  @override
  Future<void> initialize() async {
    if (throwOnInit) throw StateError('boom');
    initialized++;
  }

  @override
  Future<void> dispose() async {
    disposed++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('open-source seam initializes zero pro modules without error', () async {
    final logs = <String>[];
    final initialized = await runProBootstrap(log: logs.add);

    // The upstream airo_pro_bootstrap registers nothing; the overlay build
    // swaps in a same-named package that does. Either way this must not
    // throw, and the GA build must come back empty.
    expect(initialized, isEmpty);
    expect(logs, isEmpty);
  });

  test('entitled modules initialize; unentitled and broken ones are '
      'contained', () async {
    final entitled = _RecordingModule('a', ProFeature.epgReminders);
    final broken = _RecordingModule(
      'b',
      ProFeature.regionalRanking,
      throwOnInit: true,
    );
    final logs = <String>[];

    final initialized = await runProBootstrap(
      log: logs.add,
      entitlements: LaunchPromoEntitlements.new,
      register: (registry) {
        registry.register(entitled);
        registry.register(broken);
      },
    );

    expect(initialized, ['a']);
    expect(entitled.initialized, 1);
    expect(logs.single, contains('Pro modules initialized: a'));
  });

  test('unentitled modules never initialize', () async {
    final module = _RecordingModule('a', ProFeature.epgReminders);

    final initialized = await runProBootstrap(
      entitlements: NoEntitlements.new,
      register: (registry) => registry.register(module),
    );

    expect(initialized, isEmpty);
    expect(module.initialized, 0);
  });

  test(
    'a throwing seam degrades to the baseline instead of crashing',
    () async {
      final logs = <String>[];

      final initialized = await runProBootstrap(
        log: logs.add,
        register: (_) => throw StateError('bad overlay'),
      );

      expect(initialized, isEmpty);
      expect(logs.single, contains('Pro bootstrap failed'));
    },
  );

  test(
    'scheduleDeferredProBootstrap runs the seam after first frame',
    () async {
      final callbacks = <void Function(Duration)>[];
      final logs = <String>[];

      scheduleDeferredProBootstrap(
        addPostFrameCallback: callbacks.add,
        log: logs.add,
      );

      expect(callbacks, hasLength(1));
      callbacks.single(Duration.zero);
      // The deferred task completes (and logs) asynchronously.
      await Future<void>.delayed(Duration.zero);
      expect(logs.any((line) => line.contains('pro_bootstrap')), isTrue);
    },
  );
}
