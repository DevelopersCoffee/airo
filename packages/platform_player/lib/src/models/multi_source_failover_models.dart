import 'package:equatable/equatable.dart';

import 'playback_engine_models.dart';

enum AiroFailoverSourceHealth {
  healthy('healthy'),
  unknown('unknown'),
  degraded('degraded'),
  failed('failed');

  const AiroFailoverSourceHealth(this.stableId);

  final String stableId;
}

enum AiroFailoverTrigger {
  playbackError('playback_error'),
  stall('stall');

  const AiroFailoverTrigger(this.stableId);

  final String stableId;
}

enum AiroFailoverDecisionCode {
  switched('switched'),
  exhausted('exhausted'),
  ignored('ignored');

  const AiroFailoverDecisionCode(this.stableId);

  final String stableId;
}

class AiroFailoverSource extends Equatable {
  const AiroFailoverSource({
    required this.sourceId,
    required this.sourceHandle,
    required this.canonicalChannelId,
    this.rank = 0,
    this.health = AiroFailoverSourceHealth.unknown,
    this.resolutionHeight,
    this.lastWorkedHere = false,
  });

  final String sourceId;
  final AiroPlaybackSourceHandle sourceHandle;
  final String canonicalChannelId;
  final int rank;
  final AiroFailoverSourceHealth health;
  final int? resolutionHeight;
  final bool lastWorkedHere;

  AiroFailoverSource copyWith({
    AiroFailoverSourceHealth? health,
    bool? lastWorkedHere,
  }) {
    return AiroFailoverSource(
      sourceId: sourceId,
      sourceHandle: sourceHandle,
      canonicalChannelId: canonicalChannelId,
      rank: rank,
      health: health ?? this.health,
      resolutionHeight: resolutionHeight,
      lastWorkedHere: lastWorkedHere ?? this.lastWorkedHere,
    );
  }

  @override
  String toString() {
    return 'AiroFailoverSource('
        'sourceId: $sourceId, '
        'canonicalChannelId: $canonicalChannelId, '
        'rank: $rank, '
        'health: ${health.stableId}, '
        'resolutionHeight: $resolutionHeight, '
        'lastWorkedHere: $lastWorkedHere, '
        'sourceHandle: redacted'
        ')';
  }

  @override
  List<Object?> get props => [
    sourceId,
    sourceHandle,
    canonicalChannelId,
    rank,
    health,
    resolutionHeight,
    lastWorkedHere,
  ];
}

class AiroFailoverPolicy extends Equatable {
  const AiroFailoverPolicy({this.stallThreshold = const Duration(seconds: 4)});

  final Duration stallThreshold;

  List<AiroFailoverSource> rankSources(Iterable<AiroFailoverSource> sources) {
    final ranked = sources.toList()
      ..sort((a, b) {
        final lastWorkedCompare = _boolScore(
          b.lastWorkedHere,
        ).compareTo(_boolScore(a.lastWorkedHere));
        if (lastWorkedCompare != 0) return lastWorkedCompare;

        final healthCompare = _healthScore(
          b.health,
        ).compareTo(_healthScore(a.health));
        if (healthCompare != 0) return healthCompare;

        final resolutionCompare = (b.resolutionHeight ?? 0).compareTo(
          a.resolutionHeight ?? 0,
        );
        if (resolutionCompare != 0) return resolutionCompare;

        return a.rank.compareTo(b.rank);
      });
    return ranked;
  }

  bool shouldFailoverForStall(Duration bufferingDuration) {
    return bufferingDuration >= stallThreshold;
  }

  int _boolScore(bool value) => value ? 1 : 0;

  int _healthScore(AiroFailoverSourceHealth health) {
    return switch (health) {
      AiroFailoverSourceHealth.healthy => 3,
      AiroFailoverSourceHealth.unknown => 2,
      AiroFailoverSourceHealth.degraded => 1,
      AiroFailoverSourceHealth.failed => 0,
    };
  }

  @override
  List<Object?> get props => [stallThreshold];
}

class AiroFailoverSessionState extends Equatable {
  AiroFailoverSessionState({
    required Iterable<AiroFailoverSource> sources,
    this.currentSourceId,
    Iterable<String> failedSourceIds = const [],
  }) : sources = List.unmodifiable(sources),
       failedSourceIds = Set.unmodifiable(failedSourceIds);

  final List<AiroFailoverSource> sources;
  final String? currentSourceId;
  final Set<String> failedSourceIds;

  int get sourceCount => sources.length;

  AiroFailoverSource? get currentSource {
    final id = currentSourceId;
    if (id == null) return null;
    for (final source in sources) {
      if (source.sourceId == id) return source;
    }
    return null;
  }

  int? get currentSourceNumber {
    final current = currentSource;
    if (current == null) return null;
    return sources.indexOf(current) + 1;
  }

  AiroFailoverSessionState copyWith({
    Iterable<AiroFailoverSource>? sources,
    String? currentSourceId,
    Iterable<String>? failedSourceIds,
  }) {
    return AiroFailoverSessionState(
      sources: sources ?? this.sources,
      currentSourceId: currentSourceId ?? this.currentSourceId,
      failedSourceIds: failedSourceIds ?? this.failedSourceIds,
    );
  }

  @override
  List<Object?> get props => [sources, currentSourceId, failedSourceIds];
}

class AiroFailoverDecision extends Equatable {
  const AiroFailoverDecision({
    required this.code,
    required this.trigger,
    required this.state,
    this.nextSource,
    this.failedSourceId,
  });

  final AiroFailoverDecisionCode code;
  final AiroFailoverTrigger trigger;
  final AiroFailoverSessionState state;
  final AiroFailoverSource? nextSource;
  final String? failedSourceId;

  bool get shouldSwitch => code == AiroFailoverDecisionCode.switched;

  String get uiStatus {
    final number = state.currentSourceNumber;
    if (code == AiroFailoverDecisionCode.switched && number != null) {
      return 'switching_source_$number/${state.sourceCount}';
    }
    return code.stableId;
  }

  @override
  String toString() {
    return 'AiroFailoverDecision('
        'code: ${code.stableId}, '
        'trigger: ${trigger.stableId}, '
        'failedSourceId: $failedSourceId, '
        'nextSourceId: ${nextSource?.sourceId}, '
        'uiStatus: $uiStatus'
        ')';
  }

  @override
  List<Object?> get props => [code, trigger, state, nextSource, failedSourceId];
}

class AiroMultiSourceFailoverController {
  AiroMultiSourceFailoverController({
    required Iterable<AiroFailoverSource> sources,
    this.policy = const AiroFailoverPolicy(),
  }) : _state = AiroFailoverSessionState(sources: policy.rankSources(sources));

  final AiroFailoverPolicy policy;
  AiroFailoverSessionState _state;

  AiroFailoverSessionState get state => _state;

  AiroFailoverSource? start({String? preferredSourceId}) {
    final source = _sourceById(preferredSourceId) ?? _firstAvailableSource();
    if (source == null) return null;
    _state = _state.copyWith(currentSourceId: source.sourceId);
    return source;
  }

  AiroFailoverDecision recordPlaybackError(String sourceId) {
    return _failCurrentSource(
      sourceId: sourceId,
      trigger: AiroFailoverTrigger.playbackError,
    );
  }

  AiroFailoverDecision recordBuffering({
    required String sourceId,
    required Duration duration,
  }) {
    if (!policy.shouldFailoverForStall(duration)) {
      return AiroFailoverDecision(
        code: AiroFailoverDecisionCode.ignored,
        trigger: AiroFailoverTrigger.stall,
        state: _state,
        failedSourceId: sourceId,
      );
    }
    return _failCurrentSource(
      sourceId: sourceId,
      trigger: AiroFailoverTrigger.stall,
    );
  }

  AiroFailoverDecision _failCurrentSource({
    required String sourceId,
    required AiroFailoverTrigger trigger,
  }) {
    final failed = {..._state.failedSourceIds, sourceId};
    final downgradedSources = [
      for (final source in _state.sources)
        if (source.sourceId == sourceId)
          source.copyWith(health: AiroFailoverSourceHealth.failed)
        else
          source,
    ];
    _state = AiroFailoverSessionState(
      sources: downgradedSources,
      currentSourceId: _state.currentSourceId,
      failedSourceIds: failed,
    );

    final next = _firstAvailableSource(excluding: sourceId);
    if (next == null) {
      return AiroFailoverDecision(
        code: AiroFailoverDecisionCode.exhausted,
        trigger: trigger,
        state: _state,
        failedSourceId: sourceId,
      );
    }

    _state = _state.copyWith(currentSourceId: next.sourceId);
    return AiroFailoverDecision(
      code: AiroFailoverDecisionCode.switched,
      trigger: trigger,
      state: _state,
      nextSource: next,
      failedSourceId: sourceId,
    );
  }

  AiroFailoverSource? _firstAvailableSource({String? excluding}) {
    for (final source in policy.rankSources(_state.sources)) {
      if (source.sourceId == excluding) continue;
      if (_state.failedSourceIds.contains(source.sourceId)) continue;
      if (source.health == AiroFailoverSourceHealth.failed) continue;
      return source;
    }
    return null;
  }

  AiroFailoverSource? _sourceById(String? sourceId) {
    if (sourceId == null) return null;
    for (final source in _state.sources) {
      if (source.sourceId == sourceId) return source;
    }
    return null;
  }
}
