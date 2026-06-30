abstract interface class NativeThreadManager {
  void configureWorkerThreads(int count);
  int get activeThreadCount;
}
