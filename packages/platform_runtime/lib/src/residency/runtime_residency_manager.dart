abstract interface class RuntimeResidencyManager {
  Future<void> evaluateMemoryBudget();
  Future<void> evictLeastRecentlyUsed();
  bool canFit(int memoryRequiredMb);
}
