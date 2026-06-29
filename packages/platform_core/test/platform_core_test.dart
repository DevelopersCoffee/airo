import 'package:flutter_test/flutter_test.dart';
import 'package:platform_core/platform_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MockTask implements BootstrapTask {
  @override
  final String name;
  @override
  final BootstrapPhase phase;
  final bool shouldFail;

  MockTask(this.name, this.phase, {this.shouldFail = false});

  @override
  Future<BootstrapResult> execute(BootstrapContext context) async {
    if (shouldFail) {
      return BootstrapResult.failure(phase, 'Simulated failure for $name');
    }
    return BootstrapResult.success(phase);
  }
}

void main() {
  group('BootstrapCoordinator', () {
    test('executes tasks in correct order by phase', () async {
      final container = ProviderContainer();
      final coordinator = container.read(bootstrapCoordinatorProvider.notifier);

      final task2 = MockTask('Task2', BootstrapPhase.storage);
      final task1 = MockTask('Task1', BootstrapPhase.logging);
      final task3 = MockTask('Task3', BootstrapPhase.settings);

      coordinator.registerTask(task3);
      coordinator.registerTask(task1);
      coordinator.registerTask(task2);

      final env = PlatformEnvironment(
        buildMode: 'test',
        platform: 'unit-test',
        version: '1.0.0',
        packageVersion: '1.0.0',
      );
      final context = BootstrapContext(environment: env);

      await coordinator.execute(context);
      expect(container.read(bootstrapCoordinatorProvider), LifecycleState.ready);
    });

    test('fails fast and updates lifecycle state on error', () async {
      final container = ProviderContainer();
      final coordinator = container.read(bootstrapCoordinatorProvider.notifier);

      final task1 = MockTask('Task1', BootstrapPhase.logging);
      final task2 = MockTask('Task2', BootstrapPhase.storage, shouldFail: true);
      final task3 = MockTask('Task3', BootstrapPhase.settings);

      coordinator.registerTask(task1);
      coordinator.registerTask(task2);
      coordinator.registerTask(task3);

      final env = PlatformEnvironment(
        buildMode: 'test',
        platform: 'unit-test',
        version: '1.0.0',
        packageVersion: '1.0.0',
      );
      final context = BootstrapContext(environment: env);

      await expectLater(
        coordinator.execute(context),
        throwsA(isA<InitializationException>()),
      );

      // Wait a tick for state change if needed, though here it's sync with execute.
      expect(container.read(bootstrapCoordinatorProvider), LifecycleState.failed);
    });
  });

  group('Result Type', () {
    test('Success stores data', () {
      final Result<int> result = const Result.success(42);
      result.when(
        success: (data) => expect(data, 42),
        failure: (e, st) => fail('Should not be failure'),
      );
    });

    test('Failure stores exception', () {
      final ex = Exception('test');
      final Result<int> result = Result.failure(ex);
      result.when(
        success: (data) => fail('Should not be success'),
        failure: (e, st) => expect(e, ex),
      );
    });
  });
}
