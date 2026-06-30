import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'bootstrap_context.dart';
import 'bootstrap_metrics.dart';
import 'bootstrap_report.dart';
import 'bootstrap_registry.dart';
import 'dependency_resolver.dart';
import 'bootstrap_validator.dart';
import '../exceptions/platform_exceptions.dart';
import '../lifecycle/lifecycle_state.dart';
import '../result/result.dart';

part 'bootstrap_coordinator.g.dart';

final bootstrapReportProvider = StateProvider<BootstrapReport?>((ref) => null);
final bootstrapContextProvider = Provider<BootstrapContext>((ref) => const BootstrapContext());

@riverpod
class BootstrapCoordinator extends _$BootstrapCoordinator {
  @override
  LifecycleState build() => LifecycleState.created;

  Future<void> execute(ProviderContainer container) async {
    state = LifecycleState.initializing;
    
    // Using a simpler event bus abstraction if we don't have access to platform_events directly from core
    // We assume platform_events package handles event publishing, but we emit primitive events here if needed.
    
    final metrics = BootstrapMetrics();
    final context = container.read(bootstrapContextProvider);
    
    try {
      final registry = BootstrapRegistry();
      final resolver = DependencyResolver();
      final sortedTasks = resolver.resolve(registry.tasks);
      
      metrics.dependencyGraphDepth = sortedTasks.length;

      for (final task in sortedTasks) {
        final taskStartTime = DateTime.now();
        
        try {
          final result = await task.initialize(context);
          final duration = DateTime.now().difference(taskStartTime);
          metrics.taskDurations[task.id()] = duration;
          
          if (result is! Success) {
            if (result is FatalFailure) {
              metrics.failedTasks.add(task.id());
              throw InitializationException('Fatal failure in task "${task.id()}": ${(result).exception}');
            } else if (result is RecoverableFailure) {
              metrics.failedTasks.add(task.id());
            }
          }
        } catch (e, st) {
          metrics.failedTasks.add(task.id());
          throw InitializationException('Task ${task.id()} failed with exception', e, st);
        }
      }
      
      final validator = BootstrapValidator();
      await validator.validate(container);
      
      metrics.markFinished();
      
      final report = BootstrapReport(
        metrics: metrics,
        isSuccess: true,
      );
      
      container.read(bootstrapReportProvider.notifier).state = report;
      state = LifecycleState.ready;
      
    } catch (e) {
      metrics.markFinished();
      
      final report = BootstrapReport(
        metrics: metrics,
        isSuccess: false,
        fatalError: e.toString(),
      );
      
      container.read(bootstrapReportProvider.notifier).state = report;
      state = LifecycleState.failed;
      rethrow;
    }
  }
}
