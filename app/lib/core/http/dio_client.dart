import 'package:dio/dio.dart';
import '../errors.dart';

/// Configured Dio HTTP client with error handling
class DioClient {
  late final Dio _dio;

  DioClient({
    String? baseUrl,
    Duration connectTimeout = const Duration(seconds: 10),
    Duration receiveTimeout = const Duration(seconds: 30),
  }) {
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
    _dio.interceptors.add(_ErrorInterceptor());
    _dio.interceptors.add(_LoggingInterceptor());
  }

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
      DioExceptionType.sendTimeout =>
        TimeoutError(
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
        originalError: e,
        originalStack: e.stackTrace,
      ),
      401 => AuthError(
        'Unauthorized: $message',
        originalError: e,
        originalStack: e.stackTrace,
      ),
      403 => PermissionError(
        'Forbidden: $message',
        originalError: e,
        originalStack: e.stackTrace,
      ),
      404 => NotFoundError(
        'Not found: $message',
        originalError: e,
        originalStack: e.stackTrace,
      ),
      _ => NetworkError(
        'HTTP $statusCode: $message',
        originalError: e,
        originalStack: e.stackTrace,
      ),
    };
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

