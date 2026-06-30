
abstract class MemoryPool {
  void allocate(int sizeBytes);
  void free(int sizeBytes);
}

class CpuPool implements MemoryPool {
  @override
  void allocate(int sizeBytes) {}
  @override
  void free(int sizeBytes) {}
}

class GpuPool implements MemoryPool {
  @override
  void allocate(int sizeBytes) {}
  @override
  void free(int sizeBytes) {}
}

abstract class MemoryManager {
  CpuPool get cpu;
  GpuPool get gpu;
}
