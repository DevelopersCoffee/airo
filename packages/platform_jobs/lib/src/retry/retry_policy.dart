enum RetryStrategy {
  noRetry,
  immediate,
  linearBackoff,
  exponentialBackoff
}

class RetryPolicy {
  final RetryStrategy strategy;
  final int maxRetries;
  final Duration initialDelay;

  const RetryPolicy({
    required this.strategy,
    this.maxRetries = 0,
    this.initialDelay = Duration.zero,
  });

  const RetryPolicy.noRetry()
      : strategy = RetryStrategy.noRetry,
        maxRetries = 0,
        initialDelay = Duration.zero;
}
