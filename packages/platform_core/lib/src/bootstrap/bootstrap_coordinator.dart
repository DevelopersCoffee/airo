import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'bootstrap_context.dart';
import 'bootstrap_phase.dart';
import '../contracts/bootstrap_task.dart';
import '../exceptions/platform_exceptions.dart';
import '../lifecycle/lifecycle_state.dart';

part 'bootstrap_coordinator.g.dart';

@riverpod
class BootstrapCoordinator extends _$BootstrapCoordinator {
  final List<BootstrapTask> _tasks = [];
  
  @override
  LifecycleState build() => LifecycleState.created;

  void registerTask(BootstrapTask task) {
    _tasks.add(task);
  }

  Future<void> execute(BootstrapContext context) async {
    state = LifecycleState.initializing;
    
    // Sort tasks by phase order
    _tasks.sort((a, b) => a.phase.index.compareTo(b.phase.index));

    for (final task in _tasks) {
      try {
        final result = await task.execute(context);
        if (!result.isSuccess) {
          state = LifecycleState.failed;
          throw InitializationException(
              'Failed during ${result.phase.name}: ${result.errorMessage}');
        }
      } catch (e, st) {
        state = LifecycleState.failed;
        throw InitializationException('Task ${task.name} failed', e, st);
      }
    }
    
    state = LifecycleState.ready;
  }
}
