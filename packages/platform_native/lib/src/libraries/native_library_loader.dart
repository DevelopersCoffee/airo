abstract interface class NativeLibraryLoader {
  Future<void> loadLibrary(String name);
  bool isLoaded(String name);
  void releaseLibrary(String name);
}
