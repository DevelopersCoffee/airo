import 'package:dio/dio.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_streams/platform_streams.dart';

/// Session-only phase for the current filter's availability scan.
enum ChannelAutoScanPhase { idle, scanning, complete, cancelled }

/// Immutable product state for Auto Scan. It never contains stream URLs.
class ChannelAutoScanState {
  const ChannelAutoScanState({
    this.scopeId,
    this.phase = ChannelAutoScanPhase.idle,
    this.requestedCount = 0,
    this.completedCount = 0,
    this.availabilityByChannelId = const {},
    this.removedChannelIds = const {},
  });

  final String? scopeId;
  final ChannelAutoScanPhase phase;
  final int requestedCount;
  final int completedCount;
  final Map<String, StreamAvailability> availabilityByChannelId;
  final Set<String> removedChannelIds;

  bool get isScanning => phase == ChannelAutoScanPhase.scanning;

  int get unavailableCount => availabilityByChannelId.values
      .where((availability) => availability == StreamAvailability.unavailable)
      .length;

  bool get canRemove =>
      phase == ChannelAutoScanPhase.complete &&
      unavailableCount > 0 &&
      removedChannelIds.isEmpty;

  bool get canRestore => removedChannelIds.isNotEmpty;

  ChannelAutoScanState copyWith({
    ChannelAutoScanPhase? phase,
    int? requestedCount,
    int? completedCount,
    Map<String, StreamAvailability>? availabilityByChannelId,
    Set<String>? removedChannelIds,
  }) {
    return ChannelAutoScanState(
      scopeId: scopeId,
      phase: phase ?? this.phase,
      requestedCount: requestedCount ?? this.requestedCount,
      completedCount: completedCount ?? this.completedCount,
      availabilityByChannelId: Map.unmodifiable(
        availabilityByChannelId ?? this.availabilityByChannelId,
      ),
      removedChannelIds: Set.unmodifiable(
        removedChannelIds ?? this.removedChannelIds,
      ),
    );
  }
}

/// Product orchestration for a single, current-filter Auto Scan.
///
/// Source data remains intact. Removal is a temporary display decision scoped
/// to [scopeId], so a filter change automatically presents the source list.
class ChannelAutoScanController extends StateNotifier<ChannelAutoScanState> {
  ChannelAutoScanController({required this.probe})
    : super(const ChannelAutoScanState());

  final StreamAvailabilityProbe probe;
  StreamProbeCancellation? _cancellation;
  int _scanGeneration = 0;
  final Map<String, StreamAvailability> _cachedAvailabilityByChannelId = {};

  Future<void> start({
    required String scopeId,
    required List<IPTVChannel> channels,
    required int maxConcurrentRequests,
    String? currentPlayingChannelId,
  }) async {
    cancel();
    final generation = ++_scanGeneration;
    final cancellation = StreamProbeCancellation();
    _cancellation = cancellation;
    final playingChannel = currentPlayingChannelId == null
        ? null
        : channels
              .where((channel) => channel.id == currentPlayingChannelId)
              .firstOrNull;
    final availability = <String, StreamAvailability>{
      for (final channel in channels)
        if (_cachedAvailabilityByChannelId[channel.id] != null)
          channel.id: _cachedAvailabilityByChannelId[channel.id]!,
      if (playingChannel != null)
        playingChannel.id: StreamAvailability.available,
    };
    if (playingChannel != null) {
      _cachedAvailabilityByChannelId[playingChannel.id] =
          StreamAvailability.available;
    }
    state = ChannelAutoScanState(
      scopeId: scopeId,
      phase: ChannelAutoScanPhase.scanning,
      requestedCount: channels.length,
      completedCount: availability.length,
      availabilityByChannelId: Map.unmodifiable(availability),
    );

    final requests = channels
        .where(
          (channel) =>
              channel.id != currentPlayingChannelId &&
              !_cachedAvailabilityByChannelId.containsKey(channel.id),
        )
        .map(_toProbeRequest)
        .toList(growable: false);
    if (requests.isEmpty) {
      _cancellation = null;
      state = state.copyWith(phase: ChannelAutoScanPhase.complete);
      return;
    }
    final result = await probe.probeAll(
      requests,
      maxConcurrentRequests: maxConcurrentRequests,
      cancellation: cancellation,
      onResult: (result, completedProbeCount) {
        if (generation != _scanGeneration || cancellation.isCancelled) return;
        _cachedAvailabilityByChannelId[result.channelId] = result.availability;
        final nextAvailability = <String, StreamAvailability>{
          ...state.availabilityByChannelId,
          result.channelId: result.availability,
        };
        state = state.copyWith(
          completedCount: nextAvailability.length,
          availabilityByChannelId: nextAvailability,
        );
      },
    );
    if (generation != _scanGeneration) return;
    _cancellation = null;
    if (result.wasCancelled || cancellation.isCancelled) {
      state = state.copyWith(phase: ChannelAutoScanPhase.cancelled);
      return;
    }
    state = state.copyWith(
      phase: ChannelAutoScanPhase.complete,
      completedCount: state.availabilityByChannelId.length,
    );
  }

  void cancel() {
    _cancellation?.cancel();
    _cancellation = null;
  }

  void removeUnavailable() {
    if (!state.canRemove) return;
    state = state.copyWith(
      removedChannelIds: state.availabilityByChannelId.entries
          .where((entry) => entry.value == StreamAvailability.unavailable)
          .map((entry) => entry.key)
          .toSet(),
    );
  }

  void restore() {
    if (!state.canRestore) return;
    state = state.copyWith(removedChannelIds: const {});
  }

  List<IPTVChannel> channelsForScope({
    required String scopeId,
    required List<IPTVChannel> channels,
  }) {
    if (state.scopeId != scopeId || state.removedChannelIds.isEmpty) {
      return channels;
    }
    return channels
        .where((channel) => !state.removedChannelIds.contains(channel.id))
        .toList(growable: false);
  }

  StreamProbeRequest _toProbeRequest(IPTVChannel channel) {
    final headers = <String, String>{};
    final userAgent = channel.headers?.userAgent;
    final referrer = channel.headers?.referrer;
    if (userAgent != null) headers['User-Agent'] = userAgent;
    if (referrer != null) headers['Referer'] = referrer;
    return StreamProbeRequest(
      channelId: channel.id,
      streamUri: Uri.parse(channel.streamUrl),
      headers: headers,
    );
  }

  @override
  void dispose() {
    cancel();
    super.dispose();
  }
}

/// Dio-backed transport for the existing feature-level HTTP client.
class DioStreamProbeTransport implements StreamProbeTransport {
  DioStreamProbeTransport(this.dio);

  final Dio dio;

  @override
  Future<StreamProbeHttpResponse> get(
    StreamProbeRequest request, {
    required StreamProbeCancellation cancellation,
  }) async {
    final cancelToken = CancelToken();
    final removeCancellationListener = cancellation.onCancel(
      () => cancelToken.cancel('auto_scan_cancelled'),
    );
    try {
      // Dio documents getUri, cancellation, request headers, response type, and
      // per-request timeouts at https://pub.dev/documentation/dio/latest/dio/Dio-class.html
      // and https://pub.dev/documentation/dio/latest/dio/Options-class.html.
      // Stream mode gives us the response status without buffering a media body;
      // Range additionally asks compliant origins for only the initial bytes.
      final response = await dio.getUri<dynamic>(
        request.streamUri,
        cancelToken: cancelToken,
        options: Options(
          headers: <String, String>{
            ...request.headers,
            'Range': 'bytes=0-1023',
          },
          responseType: ResponseType.stream,
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
          persistentConnection: false,
          validateStatus: (_) => true,
        ),
      );
      cancelToken.cancel('auto_scan_response_headers_received');
      return StreamProbeHttpResponse(statusCode: response.statusCode ?? 0);
    } on DioException catch (error) {
      if (cancellation.isCancelled || error.type == DioExceptionType.cancel) {
        throw const StreamProbeTransportFailure.cancelled();
      }
      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        throw const StreamProbeTransportFailure.timeout();
      }
      throw const StreamProbeTransportFailure.network();
    } finally {
      removeCancellationListener();
    }
  }
}
