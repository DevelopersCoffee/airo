import 'dart:ffi';

abstract interface class NativeMemoryManager {
  Pointer<Void> allocate(int bytes);
  void free(Pointer<Void> pointer);
  int get allocatedBytes;
}
