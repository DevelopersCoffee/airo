abstract class MemoryRegion {}

class Heap implements MemoryRegion {}
class GpuMemory implements MemoryRegion {}
class KvCache implements MemoryRegion {}
class SharedMemory implements MemoryRegion {}
class ZeroCopyBuffers implements MemoryRegion {}

abstract class ArenaAllocator {
  dynamic allocate(int bytes);
  void free(dynamic pointer);
}

abstract class MemoryPressureMonitor {
  Stream<double> get pressureStream;
}

abstract class EvictionPolicy {
  void evict(MemoryRegion region);
}

class MemoryManager {
  MemoryManager({
    required this.heap,
    required this.gpuMemory,
    required this.kvCache,
    required this.arenaAllocator,
    required this.sharedMemory,
    required this.zeroCopyBuffers,
    required this.pressureMonitor,
    required this.evictionPolicy,
  });

  final Heap heap;
  final GpuMemory gpuMemory;
  final KvCache kvCache;
  final ArenaAllocator arenaAllocator;
  final SharedMemory sharedMemory;
  final ZeroCopyBuffers zeroCopyBuffers;
  final MemoryPressureMonitor pressureMonitor;
  final EvictionPolicy evictionPolicy;
}
