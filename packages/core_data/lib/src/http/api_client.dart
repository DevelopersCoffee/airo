import 'package:core_domain/core_domain.dart';
import 'package:dio/dio.dart';

import 'api_exception.dart';

/// HTTP API client wrapper around Dio
class ApiClient {
  ApiClient({
    required String baseUrl,
    Duration? connectTimeout,
    Duration? receiveTimeout,
    Map<String, String>? defaultHeaders,
  }) : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: connectTimeout ?? const Duration(seconds: 30),
            receiveTimeout: receiveTimeout ?? const Duration(seconds: 30),
            headers: defaultHeaders,
          ),
        );

  final Dio _dio;

  /// Add an interceptor to the client
  void addInterceptor(Interceptor interceptor) {
    _dio.interceptors.add(interceptor);
  }

  /// GET request
  Future<Result<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParams,
    T Function(dynamic data)? parser,
  }) async =>
      _executeRequest(
        () => _dio.get<dynamic>(path, queryParameters: queryParams),
        parser: parser,
      );

  /// POST request
  Future<Result<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParams,
    T Function(dynamic data)? parser,
  }) async =>
      _executeRequest(
        () => _dio.post<dynamic>(path, data: data, queryParameters: queryParams),
        parser: parser,
      );

  /// PUT request
  Future<Result<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParams,
    T Function(dynamic data)? parser,
  }) async =>
      _executeRequest(
        () => _dio.put<dynamic>(path, data: data, queryParameters: queryParams),
        parser: parser,
      );

  /// DELETE request
  Future<Result<T>> delete<T>(
    String path, {
    Map<String, dynamic>? queryParams,
    T Function(dynamic data)? parser,
  }) async =>
      _executeRequest(
        () => _dio.delete<dynamic>(path, queryParameters: queryParams),
        parser: parser,
      );

  /// PATCH request
  Future<Result<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParams,
    T Function(dynamic data)? parser,
  }) async =>
      _executeRequest(
        () => _dio.patch<dynamic>(path, data: data, queryParameters: queryParams),
        parser: parser,
      );

  Future<Result<T>> _executeRequest<T>(
    Future<Response<dynamic>> Function() request, {
    T Function(dynamic data)? parser,
  }) async {
    try {
      final response = await request();
      final data = response.data;

      if (parser != null) {
        return Success(parser(data));
      }

      // If no parser and T is dynamic or Object, return data as-is
      return Success(data as T);
    } on DioException catch (e) {
      return Failure(_mapDioException(e));
    } catch (e) {
      return Failure(UnexpectedFailure(message: e.toString(), cause: e));
    }
  }

  Failure _mapDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const NetworkFailure(message: 'Connection timeout');
      case DioExceptionType.connectionError:
        return const NetworkFailure(message: 'No internet connection');
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        if (statusCode == 401) {
          return const AuthFailure(message: 'Unauthorized');
        }
        if (statusCode == 403) {
          return const PermissionFailure();
        }
        if (statusCode == 404) {
          return const NotFoundFailure();
        }
        return ServerFailure(
          message: 'Server error: $statusCode',
          statusCode: statusCode,
        );
      case DioExceptionType.cancel:
        return const UnexpectedFailure(message: 'Request cancelled');
      default:
        return UnexpectedFailure(message: e.message ?? 'Unknown error');
    }
  }
}

