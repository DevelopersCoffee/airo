import 'dart:collection';
import '../contracts/bootstrap_task.dart';
import '../exceptions/platform_exceptions.dart';

class DependencyResolver {
  List<BootstrapTask> resolve(List<BootstrapTask> tasks) {
    final Map<String, BootstrapTask> providerMap = {};
    for (final task in tasks) {
      for (final provided in task.provides()) {
        if (providerMap.containsKey(provided)) {
          throw InitializationException('Duplicate provider for "$provided" found in task "${task.id()}"');
        }
        providerMap[provided] = task;
      }
    }

    final Map<String, List<String>> adj = {};
    final Map<String, int> inDegree = {};
    
    for (final task in tasks) {
      inDegree[task.id()] = 0;
      adj[task.id()] = [];
    }

    for (final task in tasks) {
      for (final dep in task.dependsOn()) {
        final provider = providerMap[dep];
        if (provider == null) {
          throw InitializationException('Task "${task.id()}" depends on "$dep" which is not provided by any task.');
        }
        // provider -> task edge
        adj[provider.id()]!.add(task.id());
        inDegree[task.id()] = inDegree[task.id()]! + 1;
      }
    }

    final Queue<String> queue = Queue();
    for (final task in tasks) {
      if (inDegree[task.id()] == 0) {
        queue.add(task.id());
      }
    }

    final List<String> sortedIds = [];
    while (queue.isNotEmpty) {
      final currentId = queue.removeFirst();
      sortedIds.add(currentId);
      
      for (final neighborId in adj[currentId]!) {
        inDegree[neighborId] = inDegree[neighborId]! - 1;
        if (inDegree[neighborId] == 0) {
          queue.add(neighborId);
        }
      }
    }

    if (sortedIds.length != tasks.length) {
      throw InitializationException('Circular dependency detected in bootstrap tasks');
    }

    return sortedIds.map((id) => tasks.firstWhere((t) => t.id() == id)).toList();
  }
}
