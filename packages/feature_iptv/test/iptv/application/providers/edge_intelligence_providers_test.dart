import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slm_edge_intelligence/slm_edge_intelligence.dart';

void main() {
  test('config parses rule and native backend values', () {
    expect(
      EdgeIptvConfig.fromValues(backend: 'rule').backend,
      EdgeIptvBackend.ruleBased,
    );
    expect(
      EdgeIptvConfig.fromValues(backend: 'native').backend,
      EdgeIptvBackend.nativeFfi,
    );
    expect(
      EdgeIptvConfig.fromValues(backend: 'pack').backend,
      EdgeIptvBackend.nativeFfi,
    );
    expect(
      EdgeIptvConfig.fromValues(backend: 'unknown').backend,
      EdgeIptvBackend.ruleBased,
    );
    expect(
      EdgeIptvConfig.fromValues(
        backend: 'native',
        packPath: '  /packs/media.pack  ',
      ).packPath,
      '/packs/media.pack',
    );
    final assetConfig = EdgeIptvConfig.fromValues(
      backend: 'native',
      packAsset: '  assets/packs/media.pack  ',
    );
    expect(assetConfig.packAsset, 'assets/packs/media.pack');
    expect(assetConfig.shouldInstallPack, isTrue);
  });

  test('play intent routes through parseIntent and play', () async {
    final edge = _FakeEdgeIntelligence(
      intent: const IntentResult(
        intent: 'play',
        tool: 'media.play',
        confidence: 0.94,
        constraints: {'query': 'Aaj Tak', 'live': true},
        missingFields: [],
        clarificationRequired: false,
      ),
      resolved: _resolved('rule_aaj_tak', 'Aaj Tak'),
    );
    final assistant = EdgeIptvAssistant(edge);

    final resolution = await assistant.resolveNaturalLanguage('Play Aaj Tak');

    expect(edge.calls, ['parseIntent:Play Aaj Tak', 'play:Aaj Tak']);
    expect(resolution.channel?.name, 'Aaj Tak');
    expect(
      resolution.channel?.streamUrl,
      'https://example.invalid/rule_aaj_tak.m3u8',
    );
    expect(resolution.channel?.category, ChannelCategory.news);
    expect(resolution.channel?.flavor, ChannelFlavor.hindiNews);
  });

  test('search intent routes through search before resolve', () async {
    final edge = _FakeEdgeIntelligence(
      intent: const IntentResult(
        intent: 'search',
        tool: 'media.search',
        confidence: 0.92,
        constraints: {'genre': 'sports', 'quality': 'hd'},
        missingFields: [],
        clarificationRequired: false,
      ),
      searchResult: const SearchResult(
        candidates: [
          MediaCandidate(
            id: 'rule_cricket_live',
            title: 'India Cricket Live',
            provider: 'rule_live',
            type: 'live_event',
            score: 0.99,
          ),
        ],
      ),
      resolved: _resolved('rule_cricket_live', 'India Cricket Live'),
    );
    final assistant = EdgeIptvAssistant(edge);

    final resolution = await assistant.resolveNaturalLanguage(
      'Sports in HD only',
    );

    expect(edge.calls, [
      'parseIntent:Sports in HD only',
      'search:Sports in HD only',
      'resolve:rule_cricket_live',
    ]);
    expect(resolution.channel?.streamUrl, contains('rule_cricket_live.m3u8'));
  });

  test('resume intent routes through resume', () async {
    final edge = _FakeEdgeIntelligence(
      intent: const IntentResult(
        intent: 'resume',
        tool: 'media.resume',
        confidence: 0.91,
        constraints: {'continue_watching': true},
        missingFields: [],
        clarificationRequired: false,
      ),
      resolved: _resolved('rule_sony_max', 'Sony Max'),
    );
    final assistant = EdgeIptvAssistant(edge);

    final resolution = await assistant.resolveNaturalLanguage(
      "Continue yesterday's movie",
    );

    expect(edge.calls, ['parseIntent:Continue yesterday\'s movie', 'resume']);
    expect(resolution.channel?.name, 'Sony Max');
  });

  test('recommend intent routes through recommend before resolve', () async {
    final edge = _FakeEdgeIntelligence(
      intent: const IntentResult(
        intent: 'recommend',
        tool: 'media.recommend',
        confidence: 0.88,
        constraints: {'genre': 'kids'},
        missingFields: [],
        clarificationRequired: false,
      ),
      recommendationResult: const RecommendationResult(
        candidates: [
          MediaCandidate(
            id: 'rule_pbs_kids',
            title: 'PBS Kids',
            provider: 'rule_iptv',
            type: 'live_channel',
            score: 0.86,
          ),
        ],
      ),
      resolved: _resolved('rule_pbs_kids', 'PBS Kids'),
    );
    final assistant = EdgeIptvAssistant(edge);

    final resolution = await assistant.resolveNaturalLanguage(
      'Cartoons for kids',
    );

    expect(edge.calls, [
      'parseIntent:Cartoons for kids',
      'recommend',
      'resolve:rule_pbs_kids',
    ]);
    expect(resolution.channel?.name, 'PBS Kids');
  });

  test('configured pack is installed once before intent parsing', () async {
    final edge = _FakeEdgeIntelligence(
      intent: const IntentResult(
        intent: 'play',
        tool: 'media.play',
        confidence: 0.94,
        constraints: {'query': 'Aaj Tak', 'live': true},
        missingFields: [],
        clarificationRequired: false,
      ),
      resolved: _resolved('rule_aaj_tak', 'Aaj Tak'),
    );
    final assistant = EdgeIptvAssistant(
      edge,
      config: EdgeIptvConfig.fromValues(
        backend: 'native',
        packPath: '/packs/media.pack',
      ),
    );

    await assistant.resolveNaturalLanguage('Play Aaj Tak');
    await assistant.resolveNaturalLanguage('Play Aaj Tak');

    expect(edge.calls, [
      'installPack:/packs/media.pack',
      'parseIntent:Play Aaj Tak',
      'play:Aaj Tak',
      'parseIntent:Play Aaj Tak',
      'play:Aaj Tak',
    ]);
  });

  test('configured pack asset resolves before installation', () async {
    final edge = _FakeEdgeIntelligence(
      intent: const IntentResult(
        intent: 'play',
        tool: 'media.play',
        confidence: 0.94,
        constraints: {'query': 'Aaj Tak', 'live': true},
        missingFields: [],
        clarificationRequired: false,
      ),
      resolved: _resolved('rule_aaj_tak', 'Aaj Tak'),
    );
    final assistant = EdgeIptvAssistant(
      edge,
      config: EdgeIptvConfig.fromValues(
        backend: 'native',
        packAsset: 'assets/packs/media.pack',
      ),
      packPathResolver: (config) async {
        expect(config.packAsset, 'assets/packs/media.pack');
        return '/support/edge_intelligence/packs/media.pack';
      },
    );

    await assistant.resolveNaturalLanguage('Play Aaj Tak');

    expect(edge.calls, [
      'installPack:/support/edge_intelligence/packs/media.pack',
      'parseIntent:Play Aaj Tak',
      'play:Aaj Tak',
    ]);
  });
}

ResolvedMedia _resolved(String id, String title) {
  return ResolvedMedia(
    id: id,
    title: title,
    streamUri: Uri.parse('https://example.invalid/$id.m3u8'),
    metadata: const {'genre': 'news', 'language': 'hi', 'live': true},
  );
}

final class _FakeEdgeIntelligence implements EdgeIntelligence {
  _FakeEdgeIntelligence({
    required this.intent,
    required this.resolved,
    this.searchResult = const SearchResult(candidates: []),
    this.recommendationResult = const RecommendationResult(candidates: []),
  });

  final IntentResult intent;
  final ResolvedMedia resolved;
  final SearchResult searchResult;
  final RecommendationResult recommendationResult;
  final List<String> calls = [];

  @override
  Future<SdkVersion> sdkVersion() async {
    return const SdkVersion(major: 0, minor: 1, patch: 0, abi: 0);
  }

  @override
  Future<PackInstallResult> installPack(
    ExecutionContext context,
    InstallPackCommand command,
  ) async {
    calls.add('installPack:${command.packPath}');
    return const PackInstallResult(
      packId: 'test.pack',
      version: '0.1.0',
      activated: true,
    );
  }

  @override
  Future<IntentResult> parseIntent(
    ExecutionContext context,
    ParseIntentQuery query,
  ) async {
    calls.add('parseIntent:${query.utterance}');
    return intent;
  }

  @override
  Future<SearchResult> search(
    ExecutionContext context,
    SearchQuery query,
  ) async {
    calls.add('search:${query.text}');
    return searchResult;
  }

  @override
  Future<RecommendationResult> recommend(
    ExecutionContext context,
    RecommendationQuery query,
  ) async {
    calls.add('recommend');
    return recommendationResult;
  }

  @override
  Future<ResolvedMedia> play(
    ExecutionContext context,
    PlayCommand command,
  ) async {
    calls.add('play:${command.itemId ?? command.query}');
    return resolved;
  }

  @override
  Future<ResolvedMedia?> resume(
    ExecutionContext context,
    ResumeQuery query,
  ) async {
    calls.add('resume');
    return resolved;
  }

  @override
  Future<ResolvedMedia> resolve(
    ExecutionContext context,
    ResolveQuery query,
  ) async {
    calls.add('resolve:${query.itemId}');
    return resolved;
  }
}
