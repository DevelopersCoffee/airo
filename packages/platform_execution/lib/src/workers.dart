import 'dart:async';

class WorkerDescriptor {
  const WorkerDescriptor({
    required this.id,
    required this.capabilities,
    required this.hardwareTarget,
  });
  
  final String id;
  final List<String> capabilities;
  final String hardwareTarget;
}

abstract class WorkerInstance {
  WorkerDescriptor get descriptor;
  Future<void> executeNode(dynamic node);
}

abstract class WorkerProvider {
  String get id;
  List<WorkerDescriptor> discover();
  Future<WorkerInstance> instantiate(WorkerDescriptor descriptor);
}
