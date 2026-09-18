/// Custom exception thrown by Airo Haptics when an unexpected platform error occurs.
class AiroHapticException implements Exception {
  const AiroHapticException(this.message, {this.code, this.details});

  final String message;
  final String? code;
  final dynamic details;

  @override
  String toString() {
    if (code != null) {
      return 'AiroHapticException($code): $message';
    }
    return 'AiroHapticException: $message';
  }
}
