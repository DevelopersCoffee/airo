import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform_playlist/platform_playlist.dart';

void main() {
  const sourceId = 'xtream-slice2';
  final fixedNow = DateTime.utc(2026, 7, 18, 1);
  DateTime clock() => fixedNow;

  RequestOptions req() => RequestOptions(path: '/');

  group('categorizeDioException', () {
    test('connectionTimeout → network', () {
      expect(
        categorizeDioException(
          DioException(
            requestOptions: req(),
            type: DioExceptionType.connectionTimeout,
          ),
        ),
        ProviderHealthFailureCategory.network,
      );
    });

    test('badResponse 401 → auth', () {
      expect(
        categorizeDioException(
          DioException(
            requestOptions: req(),
            type: DioExceptionType.badResponse,
            response: Response(requestOptions: req(), statusCode: 401),
          ),
        ),
        ProviderHealthFailureCategory.auth,
      );
    });

    test('badResponse 403 → auth', () {
      expect(
        categorizeDioException(
          DioException(
            requestOptions: req(),
            type: DioExceptionType.badResponse,
            response: Response(requestOptions: req(), statusCode: 403),
          ),
        ),
        ProviderHealthFailureCategory.auth,
      );
    });

    test('badResponse 500 → server', () {
      expect(
        categorizeDioException(
          DioException(
            requestOptions: req(),
            type: DioExceptionType.badResponse,
            response: Response(requestOptions: req(), statusCode: 502),
          ),
        ),
        ProviderHealthFailureCategory.server,
      );
    });

    test('badResponse 404 → client', () {
      expect(
        categorizeDioException(
          DioException(
            requestOptions: req(),
            type: DioExceptionType.badResponse,
            response: Response(requestOptions: req(), statusCode: 404),
          ),
        ),
        ProviderHealthFailureCategory.client,
      );
    });

    test('connectionError → network', () {
      expect(
        categorizeDioException(
          DioException(
            requestOptions: req(),
            type: DioExceptionType.connectionError,
          ),
        ),
        ProviderHealthFailureCategory.network,
      );
    });
  });

  group('recordFetch', () {
    test('null tracker → passthrough, no recording', () async {
      final result = await recordFetch<int>(body: () async => 42);
      expect(result, 42);
    });

    test('success → records fetchSuccess with elapsed latency', () async {
      final tracker = ProviderHealthTracker();
      final result = await recordFetch<int>(
        tracker: tracker,
        sourceId: sourceId,
        nowUtc: clock,
        body: () async => 7,
      );
      expect(result, 7);
      final snap = tracker.snapshotFor(sourceId);
      expect(snap.totalSamples, 1);
      expect(snap.lastSuccessUtc, fixedNow);
      expect(snap.p50Latency, isNotNull);
    });

    test(
      'DioException 401 → records fetchFailure(auth) and rethrows',
      () async {
        final tracker = ProviderHealthTracker();
        await expectLater(
          recordFetch<int>(
            tracker: tracker,
            sourceId: sourceId,
            nowUtc: clock,
            body: () async {
              throw DioException(
                requestOptions: req(),
                type: DioExceptionType.badResponse,
                response: Response(requestOptions: req(), statusCode: 401),
              );
            },
          ),
          throwsA(isA<DioException>()),
        );
        final snap = tracker.snapshotFor(sourceId);
        expect(snap.recentFailureCategory, ProviderHealthFailureCategory.auth);
        expect(snap.failureRate, 1.0);
        expect(snap.lastFailureUtc, fixedNow);
      },
    );

    test(
      'FormatException → records fetchFailure(malformed) and rethrows',
      () async {
        final tracker = ProviderHealthTracker();
        await expectLater(
          recordFetch<int>(
            tracker: tracker,
            sourceId: sourceId,
            nowUtc: clock,
            body: () async {
              throw const FormatException('bad json');
            },
          ),
          throwsA(isA<FormatException>()),
        );
        expect(
          tracker.snapshotFor(sourceId).recentFailureCategory,
          ProviderHealthFailureCategory.malformed,
        );
      },
    );

    test(
      'no double-recording on nested calls (single sample per outer)',
      () async {
        final tracker = ProviderHealthTracker();
        await recordFetch<int>(
          tracker: tracker,
          sourceId: sourceId,
          nowUtc: clock,
          body: () async => 1,
        );
        await recordFetch<int>(
          tracker: tracker,
          sourceId: sourceId,
          nowUtc: clock,
          body: () async => 2,
        );
        expect(tracker.snapshotFor(sourceId).totalSamples, 2);
      },
    );
  });
}
