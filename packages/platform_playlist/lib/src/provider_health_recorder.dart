import 'package:dio/dio.dart';

import 'provider_health.dart';

/// Maps a [DioException] into a [ProviderHealthFailureCategory] code.
///
/// The categories are user-facing (they seed CV-001's "likely cause"
/// hint), so the mapping is deliberately coarse. When a mapping is
/// ambiguous, fall on the side of the milder category — showing "server
/// is having issues" on a client-side bug is worse than showing
/// "cannot reach server" briefly.
String categorizeDioException(DioException error) {
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
    case DioExceptionType.connectionError:
      return ProviderHealthFailureCategory.network;
    case DioExceptionType.badCertificate:
      return ProviderHealthFailureCategory.network;
    case DioExceptionType.cancel:
      return ProviderHealthFailureCategory.network;
    case DioExceptionType.badResponse:
      final status = error.response?.statusCode ?? 0;
      if (status == 401 || status == 403) {
        return ProviderHealthFailureCategory.auth;
      }
      if (status >= 500) {
        return ProviderHealthFailureCategory.server;
      }
      return ProviderHealthFailureCategory.client;
    case DioExceptionType.unknown:
      return ProviderHealthFailureCategory.network;
  }
}

/// Runs [body], records exactly one [ProviderHealthSample] on [tracker]
/// (when non-null), and rethrows on error so callers can still react.
///
/// Any [DioException] is categorized via [categorizeDioException]; any
/// non-Dio exception (e.g. [FormatException] from JSON parsing) is
/// recorded as [ProviderHealthFailureCategory.malformed] since the HTTP
/// call itself succeeded but produced a body the caller could not use.
Future<T> recordFetch<T>({
  required Future<T> Function() body,
  ProviderHealthTracker? tracker,
  String? sourceId,
  DateTime Function()? nowUtc,
}) async {
  if (tracker == null || sourceId == null) {
    return body();
  }
  final clock = nowUtc ?? () => DateTime.now().toUtc();
  final stopwatch = Stopwatch()..start();
  try {
    final result = await body();
    tracker.record(
      ProviderHealthSample.fetchSuccess(
        sourceId: sourceId,
        timestampUtc: clock(),
        latency: stopwatch.elapsed,
      ),
    );
    return result;
  } on DioException catch (error) {
    tracker.record(
      ProviderHealthSample.fetchFailure(
        sourceId: sourceId,
        timestampUtc: clock(),
        failureCategory: categorizeDioException(error),
        latency: stopwatch.elapsed,
        httpStatus: error.response?.statusCode,
      ),
    );
    rethrow;
  } catch (_) {
    tracker.record(
      ProviderHealthSample.fetchFailure(
        sourceId: sourceId,
        timestampUtc: clock(),
        failureCategory: ProviderHealthFailureCategory.malformed,
        latency: stopwatch.elapsed,
      ),
    );
    rethrow;
  }
}
