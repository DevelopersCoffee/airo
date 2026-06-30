import '../contracts/bootstrap_task.dart';

class BootstrapRegistry {
  static final BootstrapRegistry _instance = BootstrapRegistry._internal();
  factory BootstrapRegistry() => _instance;
  BootstrapRegistry._internal();

  final List<BootstrapTask> _tasks = [];

  void register(BootstrapTask task) {
    _tasks.add(task);
  }

  List<BootstrapTask> get tasks => List.unmodifiable(_tasks);
  
  void clear() {
    _tasks.clear();
  }
}
