/// Exception thrown by API operations
class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.response,
  });

  final String message;
  final int? statusCode;
  final dynamic response;

  @override
  String toString() => 'ApiException: $message (status: $statusCode)';
}

