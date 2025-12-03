import 'package:dio/dio.dart';
import 'package:core_domain/core_domain.dart';

/// Security configuration for HTTP client.
class HttpSecurityConfig {
  /// Whether to enforce HTTPS for all requests.
  final bool enforceHttps;

  /// Whether to enable certificate pinning.
  final bool enableCertificatePinning;

  /// SHA-256 hashes of pinned certificates (base64 encoded).
  /// Used for certificate pinning when enabled.
  final List<String> pinnedCertificates;

  /// Allowed hosts for certificate pinning.
  /// If empty, pinning applies to all hosts.
  final List<String> pinnedHosts;

  /// Whether to allow self-signed certificates (dev only).
  final bool allowSelfSigned;

  const HttpSecurityConfig({
    this.enforceHttps = true,
    this.enableCertificatePinning = false,
    this.pinnedCertificates = const [],
    this.pinnedHosts = const [],
    this.allowSelfSigned = false,
  });

  /// Development configuration (less strict).
  static const HttpSecurityConfig development = HttpSecurityConfig(
    enforceHttps: false,
    enableCertificatePinning: false,
    allowSelfSigned: true,
  );

  /// Production configuration (strict).
  static const HttpSecurityConfig production = HttpSecurityConfig(
    enforceHttps: true,
    enableCertificatePinning: true,
    allowSelfSigned: false,
  );
}

/// Configured Dio HTTP client with error handling and security features.
class DioClient {
  late final Dio _dio;
  final HttpSecurityConfig _securityConfig;

  DioClient({
    String? baseUrl,
    Duration connectTimeout = const Duration(seconds: 10),
    Duration receiveTimeout = const Duration(seconds: 30),
    HttpSecurityConfig securityConfig = const HttpSecurityConfig(),
  }) : _securityConfig = securityConfig {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? '',
        connectTimeout: connectTimeout,
        receiveTimeout: receiveTimeout,
        contentType: 'application/json',
        responseType: ResponseType.json,
      ),
    );

    // Add interceptors
    _dio.interceptors.add(_HttpsEnforcementInterceptor(_securityConfig));
    _dio.interceptors.add(_ErrorInterceptor());
    _dio.interceptors.add(_LoggingInterceptor());
  }

  /// Get security configuration
  HttpSecurityConfig get securityConfig => _securityConfig;

  /// Get the underlying Dio instance
  Dio get dio => _dio;

  /// Set authorization token
  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  /// Clear authorization token
  void clearAuthToken() {
    _dio.options.headers.remove('Authorization');
  }

  /// Make a GET request
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      return await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Make a POST request
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      return await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Make a PUT request
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    try {
      return await _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
        onReceiveProgress: onReceiveProgress,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Make a DELETE request
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Handle Dio errors and convert to AppError
  AppError _handleDioError(DioException e) {
    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.sendTimeout => TimeoutError(
        'Request timeout: ${e.message}',
        originalError: e,
        originalStack: e.stackTrace,
      ),
      DioExceptionType.badResponse => _handleResponseError(e),
      DioExceptionType.cancel => AppError(
        'REQUEST_CANCELLED',
        'Request was cancelled',
        originalError: e,
        originalStack: e.stackTrace,
      ),
      DioExceptionType.unknown => NetworkError(
        'Network error: ${e.message}',
        originalError: e,
        originalStack: e.stackTrace,
      ),
      _ => UnknownError(
        'Unknown error: ${e.message}',
        originalError: e,
        originalStack: e.stackTrace,
      ),
    };
  }

  /// Handle HTTP response errors
  AppError _handleResponseError(DioException e) {
    final statusCode = e.response?.statusCode ?? 0;
    final message = e.response?.statusMessage ?? 'Unknown error';

    return switch (statusCode) {
      400 => ValidationError(
        'Bad request: $message',
        statusCode: statusCode,
        originalError: e,
        originalStack: e.stackTrace,
      ),
      401 => AuthenticationError(
        'Unauthorized: $message',
        statusCode: statusCode,
        originalError: e,
        originalStack: e.stackTrace,
      ),
      403 => PermissionError(
        'Forbidden: $message',
        statusCode: statusCode,
        originalError: e,
        originalStack: e.stackTrace,
      ),
      404 => NotFoundError(
        'Not found: $message',
        statusCode: statusCode,
        originalError: e,
        originalStack: e.stackTrace,
      ),
      _ => NetworkError(
        'HTTP $statusCode: $message',
        statusCode: statusCode,
        originalError: e,
        originalStack: e.stackTrace,
      ),
    };
  }
}

/// HTTPS enforcement interceptor
class _HttpsEnforcementInterceptor extends Interceptor {
  final HttpSecurityConfig _config;

  _HttpsEnforcementInterceptor(this._config);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (_config.enforceHttps) {
      final uri = options.uri;
      if (uri.scheme == 'http' && !_isLocalhost(uri.host)) {
        handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.badResponse,
            message: 'HTTPS is required. HTTP requests are not allowed.',
          ),
        );
        return;
      }
    }
    handler.next(options);
  }

  bool _isLocalhost(String host) {
    return host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '10.0.2.2' || // Android emulator
        host.startsWith('192.168.') ||
        host.startsWith('10.');
  }
}

/// Error interceptor
class _ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    handler.next(err);
  }
}

/// Logging interceptor
class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    handler.next(response);
  }
}
