import 'dart:async';
import '../contracts/job_cancellation_token.dart';

class DefaultCancellationTokenSource implements JobCancellationTokenSource {
  final Completer<void> _completer = Completer<void>();
  late final DefaultCancellationToken _token;

  DefaultCancellationTokenSource() {
    _token = DefaultCancellationToken(this);
  }

  @override
  JobCancellationToken get token => _token;

  @override
  void cancel() {
    if (!_completer.isCompleted) {
      _completer.complete();
    }
  }

  bool get isCancelled => _completer.isCompleted;
  Future<void> get onCancelled => _completer.future;
}

class DefaultCancellationToken implements JobCancellationToken {
  final DefaultCancellationTokenSource _source;

  DefaultCancellationToken(this._source);

  @override
  bool get isCancelled => _source.isCancelled;

  @override
  Future<void> get onCancelled => _source.onCancelled;

  @override
  void throwIfCancelled() {
    if (isCancelled) {
      throw StateError('Job was cancelled');
    }
  }
}
