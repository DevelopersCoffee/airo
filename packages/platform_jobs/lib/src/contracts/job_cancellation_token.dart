abstract interface class JobCancellationToken {
  bool get isCancelled;
  Future<void> get onCancelled;
  void throwIfCancelled();
}

abstract interface class JobCancellationTokenSource {
  JobCancellationToken get token;
  void cancel();
}
