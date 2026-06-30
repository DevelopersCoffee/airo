import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:platform_core/platform_core.dart';

class MockTask implements BootstrapTask {
  final String _id;
  final Set<String> _provides;
  final Set<String> _dependsOn;
  final bool _shouldFail;
  final bool _isFatal;
  bool executed = false;

  MockTask(this._id, this._provides, this._dependsOn, {bool shouldFail = false, bool isFatal = true}) 
      : _shouldFail = shouldFail,
        _isFatal = isFatal;

  @override
  String id() => _id;

  @override
  Set<String> provides() => _provides;

  @override
  Set<String> dependsOn() => _dependsOn;

  @override
  bool isLazy() => false;

  @override
  Future<Result<void>> initialize(BootstrapContext context) async {
    executed = true;
    if (_shouldFail) {
      return _isFatal ? FatalFailure(Exception('Simulated failure for $_id')) : RecoverableFailure(Exception('Recoverable failure for $_id'));
    }
    return const Success(null);
  }
}

void main() {
  group('DependencyResolver', () {
    late DependencyResolver resolver;

    setUp(() {
      resolver = DependencyResolver();
    });

    test('resolves simple linear dependencies', () {
      final t1 = MockTask('t1', {'a'}, {});
      final t2 = MockTask('t2', {'b'}, {'a'});
      final t3 = MockTask('t3', {'c'}, {'b'});

      final sorted = resolver.resolve([t3, t1, t2]);
      
      expect(sorted.map((t) => t.id()).toList(), ['t1', 't2', 't3']);
    });

    test('resolves complex DAG dependencies', () {
      final t1 = MockTask('db', {'database'}, {});
      final t2 = MockTask('logger', {'logging'}, {});
      final t3 = MockTask('auth', {'auth'}, {'database', 'logging'});
      final t4 = MockTask('sync', {'sync'}, {'auth'});

      final sorted = resolver.resolve([t4, t2, t1, t3]);
      
      final ids = sorted.map((t) => t.id()).toList();
      expect(ids.indexOf('auth') > ids.indexOf('db'), isTrue);
      expect(ids.indexOf('auth') > ids.indexOf('logger'), isTrue);
      expect(ids.indexOf('sync') > ids.indexOf('auth'), isTrue);
    });

    test('throws InitializationException on circular dependency', () {
      final t1 = MockTask('t1', {'a'}, {'b'});
      final t2 = MockTask('t2', {'b'}, {'a'});

      expect(
        () => resolver.resolve([t1, t2]),
        throwsA(isA<InitializationException>().having((e) => e.message, 'message', contains('Circular dependency'))),
      );
    });

    test('throws InitializationException on missing dependency', () {
      final t1 = MockTask('t1', {'a'}, {'c'});

      expect(
        () => resolver.resolve([t1]),
        throwsA(isA<InitializationException>().having((e) => e.message, 'message', contains('which is not provided'))),
      );
    });

    test('throws InitializationException on duplicate provider', () {
      final t1 = MockTask('t1', {'a'}, {});
      final t2 = MockTask('t2', {'a'}, {});

      expect(
        () => resolver.resolve([t1, t2]),
        throwsA(isA<InitializationException>().having((e) => e.message, 'message', contains('Duplicate provider'))),
      );
    });
  });

  group('BootstrapCoordinator', () {
    test('executes tasks in topological order', () async {
      final container = ProviderContainer();
      final coordinator = container.read(bootstrapCoordinatorProvider.notifier);
      
      final registry = BootstrapRegistry();
      registry.clear();
      
      final t1 = MockTask('t1', {'a'}, {});
      final t2 = MockTask('t2', {'b'}, {'a'});
      
      registry.register(t1);
      registry.register(t2);

      await coordinator.execute(container);

      expect(t1.executed, isTrue);
      expect(t2.executed, isTrue);
      expect(coordinator.state, LifecycleState.ready);
      
      final report = container.read(bootstrapReportProvider);
      expect(report, isNotNull);
      expect(report!.isSuccess, isTrue);
      expect(report.metrics.dependencyGraphDepth, 2);
    });

    test('fails fast on fatal failure', () async {
      final container = ProviderContainer();
      final coordinator = container.read(bootstrapCoordinatorProvider.notifier);
      
      final registry = BootstrapRegistry();
      registry.clear();
      
      final t1 = MockTask('t1', {'a'}, {}, shouldFail: true);
      final t2 = MockTask('t2', {'b'}, {'a'});
      
      registry.register(t1);
      registry.register(t2);

      await expectLater(
        coordinator.execute(container),
        throwsA(isA<InitializationException>()),
      );

      expect(t1.executed, isTrue);
      expect(t2.executed, isFalse);
      expect(coordinator.state, LifecycleState.failed);
      
      final report = container.read(bootstrapReportProvider);
      expect(report, isNotNull);
      expect(report!.isSuccess, isFalse);
      expect(report.metrics.failedTasks, contains('t1'));
    });
  });
}
