import 'package:platform_identity/platform_identity.dart';

enum ResourceState {
  allocated,
  active,
  suspended,
  released,
  faulted,
}

abstract class PlatformResource {
  PlatformIdentifier get id;
  ResourceState get state;
  int get memoryFootprintBytes;
  
  void allocate();
  void activate();
  void suspend();
  void release();
}

class ModelResource extends PlatformResource {
  ModelResource(this.id);
  @override
  final PlatformIdentifier id;
  
  ResourceState _state = ResourceState.allocated;
  @override
  ResourceState get state => _state;
  
  @override
  int get memoryFootprintBytes => 0; // TODO: implement
  
  @override
  void allocate() => _state = ResourceState.allocated;
  
  @override
  void activate() => _state = ResourceState.active;
  
  @override
  void suspend() => _state = ResourceState.suspended;
  
  @override
  void release() => _state = ResourceState.released;
}
// Additional resources like SessionResource, PluginResource, EngineResource, ToolResource follow similar patterns.
