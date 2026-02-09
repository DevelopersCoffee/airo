import 'dart:async';

/// Types of errors that can occur during Beats playback
enum BeatsErrorType {
  /// Temporary network loss - auto retry
  networkLost,

  /// Stream URL expired - re-resolve and resume
  streamExpired,

  /// Source unavailable (video deleted, private) - skip track
  sourceUnavailable,

  /// Rate limited - wait and retry
  quotaExceeded,

  /// Server error - failover to backup
  serverError,

  /// Unrecoverable error - show error to user
  unrecoverable,
}

/// Status of recovery attempt
enum RecoveryStatus {
  /// Not attempting recovery
  idle,

  /// Currently attempting recovery
  recovering,

  /// Recovery successful
  recovered,

  /// Recovery failed, will retry
  retrying,

  /// All retries exhausted
  failed,

  /// Skipping to next track
  skipping,
}

/// Recovery event for stream
class RecoveryEvent {
  final RecoveryStatus status;
  final BeatsErrorType? errorType;
  final String? message;
  final int attemptNumber;
  final Duration? nextRetryIn;

  const RecoveryEvent({
    required this.status,
    this.errorType,
    this.message,
    this.attemptNumber = 0,
    this.nextRetryIn,
  });
}

/// Service for handling error recovery during playback
class BeatsRecoveryService {
  static const int _maxRetries = 5;
  static const List<Duration> _retryDelays = [
    Duration.zero,
    Duration(seconds: 1),
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
  ];

  final _recoveryController = StreamController<RecoveryEvent>.broadcast();

  int _currentRetryCount = 0;
  bool _isRecovering = false;
  Timer? _retryTimer;

  /// Stream of recovery events
  Stream<RecoveryEvent> get recoveryStream => _recoveryController.stream;

  /// Current retry count
  int get retryCount => _currentRetryCount;

  /// Whether currently recovering
  bool get isRecovering => _isRecovering;

  /// Get delay for next retry
  Duration get nextRetryDelay {
    if (_currentRetryCount >= _retryDelays.length) {
      return _retryDelays.last;
    }
    return _retryDelays[_currentRetryCount];
  }

  /// Classify error type from exception
  BeatsErrorType classifyError(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('socket')) {
      return BeatsErrorType.networkLost;
    }

    if (errorString.contains('403') ||
        errorString.contains('forbidden') ||
        errorString.contains('expired')) {
      return BeatsErrorType.streamExpired;
    }

    if (errorString.contains('404') ||
        errorString.contains('not found') ||
        errorString.contains('unavailable') ||
        errorString.contains('private')) {
      return BeatsErrorType.sourceUnavailable;
    }

    if (errorString.contains('429') ||
        errorString.contains('rate limit') ||
        errorString.contains('quota')) {
      return BeatsErrorType.quotaExceeded;
    }

    if (errorString.contains('500') ||
        errorString.contains('502') ||
        errorString.contains('503') ||
        errorString.contains('server')) {
      return BeatsErrorType.serverError;
    }

    return BeatsErrorType.unrecoverable;
  }

  /// Determine if error type is recoverable
  bool isRecoverable(BeatsErrorType type) {
    switch (type) {
      case BeatsErrorType.networkLost:
      case BeatsErrorType.streamExpired:
      case BeatsErrorType.quotaExceeded:
      case BeatsErrorType.serverError:
        return true;
      case BeatsErrorType.sourceUnavailable:
      case BeatsErrorType.unrecoverable:
        return false;
    }
  }

  /// Attempt recovery for an error
  Future<bool> attemptRecovery({
    required BeatsErrorType errorType,
    required String trackId,
    required Future<bool> Function() retryAction,
    Future<void> Function()? onSkip,
  }) async {
    if (_isRecovering) return false;

    // Check if error is recoverable
    if (!isRecoverable(errorType)) {
      _recoveryController.add(
        RecoveryEvent(
          status: RecoveryStatus.skipping,
          errorType: errorType,
          message: 'Track unavailable, skipping...',
        ),
      );

      if (onSkip != null) {
        await onSkip();
      }
      return false;
    }

    _isRecovering = true;
    _currentRetryCount = 0;

    while (_currentRetryCount < _maxRetries) {
      _recoveryController.add(
        RecoveryEvent(
          status: RecoveryStatus.recovering,
          errorType: errorType,
          attemptNumber: _currentRetryCount + 1,
          message:
              'Attempting recovery (${_currentRetryCount + 1}/$_maxRetries)...',
        ),
      );

      // Wait before retry (except first attempt)
      if (_currentRetryCount > 0) {
        final delay = nextRetryDelay;
        _recoveryController.add(
          RecoveryEvent(
            status: RecoveryStatus.retrying,
            errorType: errorType,
            attemptNumber: _currentRetryCount + 1,
            nextRetryIn: delay,
            message: 'Retrying in ${delay.inSeconds}s...',
          ),
        );
        await Future.delayed(delay);
      }

      try {
        final success = await retryAction();
        if (success) {
          _recoveryController.add(
            const RecoveryEvent(
              status: RecoveryStatus.recovered,
              message: 'Playback recovered',
            ),
          );
          _reset();
          return true;
        }
      } catch (e) {
        // Continue to next retry
        print('[BeatsRecovery] Retry ${_currentRetryCount + 1} failed: $e');
      }

      _currentRetryCount++;
    }

    // All retries exhausted
    _recoveryController.add(
      RecoveryEvent(
        status: RecoveryStatus.failed,
        errorType: errorType,
        message: 'Recovery failed after $_maxRetries attempts',
      ),
    );

    // Skip to next track
    if (onSkip != null) {
      _recoveryController.add(
        RecoveryEvent(
          status: RecoveryStatus.skipping,
          errorType: errorType,
          message: 'Skipping to next track...',
        ),
      );
      await onSkip();
    }

    _reset();
    return false;
  }

  /// Cancel ongoing recovery
  void cancelRecovery() {
    _retryTimer?.cancel();
    _reset();
    _recoveryController.add(
      const RecoveryEvent(
        status: RecoveryStatus.idle,
        message: 'Recovery cancelled',
      ),
    );
  }

  /// Reset recovery state
  void _reset() {
    _isRecovering = false;
    _currentRetryCount = 0;
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  /// Handle network connectivity change
  void onNetworkRestored() {
    if (_isRecovering) {
      // Speed up recovery when network is restored
      _retryTimer?.cancel();
    }
  }

  /// Dispose resources
  void dispose() {
    _retryTimer?.cancel();
    _recoveryController.close();
  }
}
