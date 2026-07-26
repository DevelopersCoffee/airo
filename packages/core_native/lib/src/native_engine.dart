import 'api/native_engine.dart' as frb;
import 'native_bridge.dart';

class AiroNativeRecommendationInput {
  const AiroNativeRecommendationInput({
    required this.id,
    required this.title,
    required this.genreAffinity,
    required this.providerAffinity,
    required this.languageAffinity,
    required this.preferredTime,
    required this.deviceFit,
    this.completionPermille,
    this.lastWatchedAgeDays,
  });

  final String id;
  final String title;
  final int genreAffinity;
  final int providerAffinity;
  final int languageAffinity;
  final int? completionPermille;
  final int? lastWatchedAgeDays;
  final bool preferredTime;
  final bool deviceFit;
}

class AiroNativeRecommendationScore {
  const AiroNativeRecommendationScore({
    required this.id,
    required this.score,
    required this.genrePoints,
    required this.providerPoints,
    required this.languagePoints,
    required this.completionPoints,
    required this.recencyPoints,
    required this.timeBucketPoints,
    required this.deviceFitPoints,
  });

  final String id;
  final int score;
  final int genrePoints;
  final int providerPoints;
  final int languagePoints;
  final int completionPoints;
  final int recencyPoints;
  final int timeBucketPoints;
  final int deviceFitPoints;
}

class AiroVectorClockCounter {
  const AiroVectorClockCounter({required this.nodeId, required this.counter});

  final String nodeId;
  final int counter;
}

enum AiroVectorClockRelation {
  equal,
  leftDominates,
  rightDominates,
  concurrent,
}

enum AiroSubtitleFormat { srt, webVtt }

class AiroSubtitleCue {
  const AiroSubtitleCue({
    required this.startMillis,
    required this.endMillis,
    required this.text,
  });

  final int startMillis;
  final int endMillis;
  final String text;
}

class AiroSubtitleParseResult {
  const AiroSubtitleParseResult({
    required this.cues,
    required this.malformedCueCount,
    required this.truncated,
  });

  final List<AiroSubtitleCue> cues;
  final int malformedCueCount;
  final bool truncated;
}

abstract interface class AiroNativeEngine {
  Future<List<AiroNativeRecommendationScore>> rankRecommendations(
    List<AiroNativeRecommendationInput> candidates,
  );

  Future<AiroVectorClockRelation> compareVectorClocks({
    required List<AiroVectorClockCounter> left,
    required List<AiroVectorClockCounter> right,
  });

  Future<AiroSubtitleParseResult> parseSubtitles({
    required String content,
    required AiroSubtitleFormat format,
  });
}

class NativePreferredAiroEngine implements AiroNativeEngine {
  const NativePreferredAiroEngine({
    this.native = const FrbAiroNativeEngine(),
    this.fallback = const DartAiroNativeEngine(),
  });

  final AiroNativeEngine native;
  final AiroNativeEngine fallback;

  @override
  Future<List<AiroNativeRecommendationScore>> rankRecommendations(
    List<AiroNativeRecommendationInput> candidates,
  ) async {
    try {
      return await native.rankRecommendations(candidates);
    } on Object {
      return fallback.rankRecommendations(candidates);
    }
  }

  @override
  Future<AiroVectorClockRelation> compareVectorClocks({
    required List<AiroVectorClockCounter> left,
    required List<AiroVectorClockCounter> right,
  }) async {
    try {
      return await native.compareVectorClocks(left: left, right: right);
    } on Object {
      return fallback.compareVectorClocks(left: left, right: right);
    }
  }

  @override
  Future<AiroSubtitleParseResult> parseSubtitles({
    required String content,
    required AiroSubtitleFormat format,
  }) async {
    try {
      return await native.parseSubtitles(content: content, format: format);
    } on Object {
      return fallback.parseSubtitles(content: content, format: format);
    }
  }
}

class FrbAiroNativeEngine implements AiroNativeEngine {
  const FrbAiroNativeEngine();

  Future<void> _requireBridge() async {
    if (!await initializeCoreNativeBridge()) {
      throw StateError('core_native_unavailable');
    }
  }

  @override
  Future<List<AiroNativeRecommendationScore>> rankRecommendations(
    List<AiroNativeRecommendationInput> candidates,
  ) async {
    await _requireBridge();
    final scores = await frb.rankRecommendations(
      candidates: [
        for (final candidate in candidates)
          frb.RecommendationCandidate(
            id: candidate.id,
            title: candidate.title,
            genreAffinity: candidate.genreAffinity,
            providerAffinity: candidate.providerAffinity,
            languageAffinity: candidate.languageAffinity,
            completionPermille: candidate.completionPermille,
            lastWatchedAgeDays: candidate.lastWatchedAgeDays,
            preferredTime: candidate.preferredTime,
            deviceFit: candidate.deviceFit,
          ),
      ],
    );
    return List.unmodifiable(
      scores.map(
        (score) => AiroNativeRecommendationScore(
          id: score.id,
          score: score.score,
          genrePoints: score.genrePoints,
          providerPoints: score.providerPoints,
          languagePoints: score.languagePoints,
          completionPoints: score.completionPoints,
          recencyPoints: score.recencyPoints,
          timeBucketPoints: score.timeBucketPoints,
          deviceFitPoints: score.deviceFitPoints,
        ),
      ),
    );
  }

  @override
  Future<AiroVectorClockRelation> compareVectorClocks({
    required List<AiroVectorClockCounter> left,
    required List<AiroVectorClockCounter> right,
  }) async {
    await _requireBridge();
    final relation = await frb.compareVectorClocks(
      left: [
        for (final counter in left)
          frb.VectorClockCounter(
            nodeId: counter.nodeId,
            counter: BigInt.from(counter.counter),
          ),
      ],
      right: [
        for (final counter in right)
          frb.VectorClockCounter(
            nodeId: counter.nodeId,
            counter: BigInt.from(counter.counter),
          ),
      ],
    );
    return AiroVectorClockRelation.values[relation.index];
  }

  @override
  Future<AiroSubtitleParseResult> parseSubtitles({
    required String content,
    required AiroSubtitleFormat format,
  }) async {
    await _requireBridge();
    final result = await frb.parseSubtitles(
      content: content,
      format: frb.SubtitleFormat.values[format.index],
    );
    return AiroSubtitleParseResult(
      cues: List.unmodifiable(
        result.cues.map(
          (cue) => AiroSubtitleCue(
            startMillis: cue.startMillis.toInt(),
            endMillis: cue.endMillis.toInt(),
            text: cue.text,
          ),
        ),
      ),
      malformedCueCount: result.malformedCueCount,
      truncated: result.truncated,
    );
  }
}

class DartAiroNativeEngine implements AiroNativeEngine {
  const DartAiroNativeEngine();

  static const int _maxSubtitleBytes = 2 * 1024 * 1024;

  @override
  Future<List<AiroNativeRecommendationScore>> rankRecommendations(
    List<AiroNativeRecommendationInput> candidates,
  ) async {
    final titles = {for (final item in candidates) item.id: item.title};
    final result = candidates.map((candidate) {
      final genre = candidate.genreAffinity * 3;
      final provider = candidate.providerAffinity * 2;
      final language = candidate.languageAffinity * 2;
      final completion = switch (candidate.completionPermille) {
        final value? when value >= 900 => -5000,
        final value? when value >= 50 => 150,
        _ => 0,
      };
      final recency = switch (candidate.lastWatchedAgeDays) {
        final value? when value <= 7 => 40,
        final value? when value <= 30 => 15,
        _ => 0,
      };
      final time = candidate.preferredTime ? 50 : 0;
      final device = candidate.deviceFit ? 25 : 0;
      return AiroNativeRecommendationScore(
        id: candidate.id,
        score:
            genre + provider + language + completion + recency + time + device,
        genrePoints: genre,
        providerPoints: provider,
        languagePoints: language,
        completionPoints: completion,
        recencyPoints: recency,
        timeBucketPoints: time,
        deviceFitPoints: device,
      );
    }).toList();
    // ignore: cascade_invocations
    result.sort((left, right) {
      final score = right.score.compareTo(left.score);
      if (score != 0) return score;
      final title = (titles[left.id] ?? '').toLowerCase().compareTo(
        (titles[right.id] ?? '').toLowerCase(),
      );
      return title != 0 ? title : left.id.compareTo(right.id);
    });
    return List.unmodifiable(result);
  }

  @override
  Future<AiroVectorClockRelation> compareVectorClocks({
    required List<AiroVectorClockCounter> left,
    required List<AiroVectorClockCounter> right,
  }) async {
    final leftMap = _clockMap(left);
    final rightMap = _clockMap(right);
    final nodes = {...leftMap.keys, ...rightMap.keys};
    var leftGreater = false;
    var rightGreater = false;
    for (final node in nodes) {
      final leftValue = leftMap[node] ?? 0;
      final rightValue = rightMap[node] ?? 0;
      leftGreater |= leftValue > rightValue;
      rightGreater |= rightValue > leftValue;
    }
    return switch ((leftGreater, rightGreater)) {
      (false, false) => AiroVectorClockRelation.equal,
      (true, false) => AiroVectorClockRelation.leftDominates,
      (false, true) => AiroVectorClockRelation.rightDominates,
      (true, true) => AiroVectorClockRelation.concurrent,
    };
  }

  Map<String, int> _clockMap(List<AiroVectorClockCounter> values) {
    final result = <String, int>{};
    for (final value in values) {
      final current = result[value.nodeId] ?? 0;
      if (value.counter > current) result[value.nodeId] = value.counter;
    }
    return result;
  }

  @override
  Future<AiroSubtitleParseResult> parseSubtitles({
    required String content,
    required AiroSubtitleFormat format,
  }) async {
    if (content.length > _maxSubtitleBytes) {
      return const AiroSubtitleParseResult(
        cues: [],
        malformedCueCount: 0,
        truncated: true,
      );
    }
    final normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final cues = <AiroSubtitleCue>[];
    var malformed = 0;
    for (final block in normalized.split('\n\n')) {
      final lines = block
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .toList();
      if (lines.isEmpty ||
          (format == AiroSubtitleFormat.webVtt &&
              lines.first.trim().toUpperCase() == 'WEBVTT')) {
        continue;
      }
      final timingIndex = lines.first.contains('-->') ? 0 : 1;
      if (timingIndex >= lines.length || !lines[timingIndex].contains('-->')) {
        malformed++;
        continue;
      }
      final timing = lines[timingIndex].split('-->');
      final endToken = timing.length == 2
          ? timing[1].trim().split(RegExp(r'\s+')).first
          : '';
      final start = _timestamp(timing.first.trim(), format);
      final end = _timestamp(endToken, format);
      final text = lines.skip(timingIndex + 1).join('\n').trim();
      if (start == null || end == null || end <= start || text.isEmpty) {
        malformed++;
        continue;
      }
      cues.add(AiroSubtitleCue(startMillis: start, endMillis: end, text: text));
    }
    cues.sort((left, right) {
      final start = left.startMillis.compareTo(right.startMillis);
      if (start != 0) return start;
      final end = left.endMillis.compareTo(right.endMillis);
      return end != 0 ? end : left.text.compareTo(right.text);
    });
    return AiroSubtitleParseResult(
      cues: List.unmodifiable(cues),
      malformedCueCount: malformed,
      truncated: false,
    );
  }

  int? _timestamp(String value, AiroSubtitleFormat format) {
    final normalized = format == AiroSubtitleFormat.srt
        ? value.replaceAll(',', '.')
        : value;
    final segments = normalized.split(':');
    late final int hours;
    late final int minutes;
    late final String seconds;
    if (segments.length == 3) {
      hours = int.tryParse(segments[0]) ?? -1;
      minutes = int.tryParse(segments[1]) ?? -1;
      seconds = segments[2];
    } else if (segments.length == 2 && format == AiroSubtitleFormat.webVtt) {
      hours = 0;
      minutes = int.tryParse(segments[0]) ?? -1;
      seconds = segments[1];
    } else {
      return null;
    }
    final secondParts = seconds.split('.');
    if (hours < 0 ||
        minutes < 0 ||
        minutes >= 60 ||
        secondParts.length != 2 ||
        secondParts[1].length != 3) {
      return null;
    }
    final wholeSeconds = int.tryParse(secondParts[0]);
    final millis = int.tryParse(secondParts[1]);
    if (wholeSeconds == null ||
        wholeSeconds >= 60 ||
        millis == null ||
        millis >= 1000) {
      return null;
    }
    return hours * 3600000 + minutes * 60000 + wholeSeconds * 1000 + millis;
  }
}
