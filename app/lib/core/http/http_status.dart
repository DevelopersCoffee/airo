/// HTTP status code model with dog image support
class HttpStatus {
  final int code;
  final String message;
  final String description;
  final HttpStatusCategory category;

  const HttpStatus({
    required this.code,
    required this.message,
    required this.description,
    required this.category,
  });

  /// Get dog image URL from http.dog
  String get dogImageUrl => 'https://http.dog/$code.jpg';

  /// Get status color based on category
  HttpStatusColor get color => category.color;

  @override
  String toString() => '$code $message';
}

/// HTTP status categories
enum HttpStatusCategory {
  informational,
  success,
  redirection,
  clientError,
  serverError,
  unknown;

  HttpStatusColor get color {
    return switch (this) {
      HttpStatusCategory.informational => HttpStatusColor.blue,
      HttpStatusCategory.success => HttpStatusColor.green,
      HttpStatusCategory.redirection => HttpStatusColor.yellow,
      HttpStatusCategory.clientError => HttpStatusColor.orange,
      HttpStatusCategory.serverError => HttpStatusColor.red,
      HttpStatusCategory.unknown => HttpStatusColor.grey,
    };
  }
}

/// Status colors
enum HttpStatusColor { blue, green, yellow, orange, red, grey }

/// HTTP status code registry
class HttpStatusCodes {
  HttpStatusCodes._();

  /// Get status by code
  static HttpStatus fromCode(int code) {
    return _statusMap[code] ??
        HttpStatus(
          code: code,
          message: 'Unknown',
          description: 'Unknown status code',
          category: HttpStatusCategory.unknown,
        );
  }

  /// Get category from code
  static HttpStatusCategory getCategoryFromCode(int code) {
    if (code >= 100 && code < 200) return HttpStatusCategory.informational;
    if (code >= 200 && code < 300) return HttpStatusCategory.success;
    if (code >= 300 && code < 400) return HttpStatusCategory.redirection;
    if (code >= 400 && code < 500) return HttpStatusCategory.clientError;
    if (code >= 500 && code < 600) return HttpStatusCategory.serverError;
    return HttpStatusCategory.unknown;
  }

  /// All status codes
  static List<HttpStatus> get allStatuses => _statusMap.values.toList();

  /// Status codes by category
  static List<HttpStatus> getByCategory(HttpStatusCategory category) {
    return _statusMap.values
        .where((status) => status.category == category)
        .toList();
  }

  // Common status codes
  static const ok = 200;
  static const created = 201;
  static const accepted = 202;
  static const noContent = 204;
  static const movedPermanently = 301;
  static const found = 302;
  static const notModified = 304;
  static const badRequest = 400;
  static const unauthorized = 401;
  static const forbidden = 403;
  static const notFound = 404;
  static const methodNotAllowed = 405;
  static const requestTimeout = 408;
  static const conflict = 409;
  static const gone = 410;
  static const imATeapot = 418;
  static const tooManyRequests = 429;
  static const internalServerError = 500;
  static const notImplemented = 501;
  static const badGateway = 502;
  static const serviceUnavailable = 503;
  static const gatewayTimeout = 504;

  /// Status code map
  static final Map<int, HttpStatus> _statusMap = {
    // 1xx Informational
    100: const HttpStatus(
      code: 100,
      message: 'Continue',
      description: 'The server has received the request headers',
      category: HttpStatusCategory.informational,
    ),
    101: const HttpStatus(
      code: 101,
      message: 'Switching Protocols',
      description: 'The requester has asked to switch protocols',
      category: HttpStatusCategory.informational,
    ),

    // 2xx Success
    200: const HttpStatus(
      code: 200,
      message: 'OK',
      description: 'The request was successful',
      category: HttpStatusCategory.success,
    ),
    201: const HttpStatus(
      code: 201,
      message: 'Created',
      description: 'The request was successful and a resource was created',
      category: HttpStatusCategory.success,
    ),
    202: const HttpStatus(
      code: 202,
      message: 'Accepted',
      description: 'The request has been accepted for processing',
      category: HttpStatusCategory.success,
    ),
    204: const HttpStatus(
      code: 204,
      message: 'No Content',
      description: 'The request was successful but there is no content',
      category: HttpStatusCategory.success,
    ),

    // 3xx Redirection
    301: const HttpStatus(
      code: 301,
      message: 'Moved Permanently',
      description: 'The resource has been moved permanently',
      category: HttpStatusCategory.redirection,
    ),
    302: const HttpStatus(
      code: 302,
      message: 'Found',
      description: 'The resource has been found at a different location',
      category: HttpStatusCategory.redirection,
    ),
    304: const HttpStatus(
      code: 304,
      message: 'Not Modified',
      description: 'The resource has not been modified',
      category: HttpStatusCategory.redirection,
    ),

    // 4xx Client Errors
    400: const HttpStatus(
      code: 400,
      message: 'Bad Request',
      description: 'The server cannot process the request',
      category: HttpStatusCategory.clientError,
    ),
    401: const HttpStatus(
      code: 401,
      message: 'Unauthorized',
      description: 'Authentication is required',
      category: HttpStatusCategory.clientError,
    ),
    403: const HttpStatus(
      code: 403,
      message: 'Forbidden',
      description: 'You do not have permission to access this resource',
      category: HttpStatusCategory.clientError,
    ),
    404: const HttpStatus(
      code: 404,
      message: 'Not Found',
      description: 'The requested resource was not found',
      category: HttpStatusCategory.clientError,
    ),
    405: const HttpStatus(
      code: 405,
      message: 'Method Not Allowed',
      description: 'The request method is not supported',
      category: HttpStatusCategory.clientError,
    ),
    408: const HttpStatus(
      code: 408,
      message: 'Request Timeout',
      description: 'The server timed out waiting for the request',
      category: HttpStatusCategory.clientError,
    ),
    409: const HttpStatus(
      code: 409,
      message: 'Conflict',
      description: 'The request conflicts with the current state',
      category: HttpStatusCategory.clientError,
    ),
    410: const HttpStatus(
      code: 410,
      message: 'Gone',
      description: 'The resource is no longer available',
      category: HttpStatusCategory.clientError,
    ),
    418: const HttpStatus(
      code: 418,
      message: 'I\'m a Teapot',
      description: 'The server refuses to brew coffee because it is a teapot',
      category: HttpStatusCategory.clientError,
    ),
    429: const HttpStatus(
      code: 429,
      message: 'Too Many Requests',
      description: 'You have sent too many requests',
      category: HttpStatusCategory.clientError,
    ),

    // 5xx Server Errors
    500: const HttpStatus(
      code: 500,
      message: 'Internal Server Error',
      description: 'The server encountered an unexpected error',
      category: HttpStatusCategory.serverError,
    ),
    501: const HttpStatus(
      code: 501,
      message: 'Not Implemented',
      description: 'The server does not support this functionality',
      category: HttpStatusCategory.serverError,
    ),
    502: const HttpStatus(
      code: 502,
      message: 'Bad Gateway',
      description: 'The server received an invalid response',
      category: HttpStatusCategory.serverError,
    ),
    503: const HttpStatus(
      code: 503,
      message: 'Service Unavailable',
      description: 'The server is temporarily unavailable',
      category: HttpStatusCategory.serverError,
    ),
    504: const HttpStatus(
      code: 504,
      message: 'Gateway Timeout',
      description: 'The server did not receive a timely response',
      category: HttpStatusCategory.serverError,
    ),
  };
}
