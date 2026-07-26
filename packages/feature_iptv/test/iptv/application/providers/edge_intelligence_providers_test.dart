import 'package:core_edge_intelligence/core_edge_intelligence.dart';
import 'package:feature_iptv/feature_iptv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:slm_edge_intelligence/slm_edge_intelligence.dart';

void main() {
  test('config parses rule, native, and pack values', () {
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
  });

  test('high-confidence intent is validated then locally executed', () async {
    final edge = _FakeEdge(
      const IntentResult(
        intent: 'browse',
        tool: 'media.search',
        confidence: 0.94,
        constraints: {'genre': 'sports', 'country': 'India'},
        missingFields: [],
        clarificationRequired: false,
      ),
    );
    final executor = _RecordingExecutor(['sports']);
    final assistant = _assistant(edge, executor);

    final resolution = await assistant.resolveNaturalLanguage(
      'Show every India match today',
    );

    expect(edge.contexts.single.network, NetworkState.offline);
    expect(executor.commands.single.intent, MediaIntent.browse);
    expect(executor.commands.single.confidence, 0.94);
    expect(resolution.channel?.id, 'sports');
    expect(resolution.usedFallback, isFalse);
    expect(resolution.elapsed, isNot(Duration.zero));
  });

  test('low confidence falls back to deterministic original query', () async {
    final edge = _FakeEdge(
      const IntentResult(
        intent: 'browse',
        tool: 'media.search',
        confidence: 0.4,
        constraints: {'genre': 'kids'},
        missingFields: [],
        clarificationRequired: false,
      ),
    );
    final executor = _RecordingExecutor(['kids']);
    final assistant = _assistant(edge, executor);

    final resolution = await assistant.resolveNaturalLanguage('Kids cartoons');

    expect(executor.commands, hasLength(1));
    expect(executor.commands.single.intent, MediaIntent.search);
    expect(executor.commands.single.entities.single.value, 'Kids cartoons');
    expect(resolution.usedFallback, isTrue);
  });

  test(
    'unsupported output is rejected before executor and falls back',
    () async {
      final edge = _FakeEdge(
        const IntentResult(
          intent: 'delete_everything',
          tool: 'unknown',
          confidence: 0.99,
          constraints: {},
          missingFields: [],
          clarificationRequired: false,
        ),
      );
      final executor = _RecordingExecutor(['local']);
      final assistant = _assistant(edge, executor);

      final resolution = await assistant.resolveNaturalLanguage('Local news');

      expect(executor.commands, hasLength(1));
      expect(executor.commands.single.intent, MediaIntent.search);
      expect(resolution.usedFallback, isTrue);
    },
  );

  test('model failure falls back without exposing the exception', () async {
    final edge = _FakeEdge.failure();
    final executor = _RecordingExecutor(const []);
    final assistant = _assistant(edge, executor);

    final resolution = await assistant.resolveNaturalLanguage('News');

    expect(resolution.message, 'No local channel or programme matched.');
    expect(resolution.usedFallback, isTrue);
  });

  test('resume uses recent channel and does not search', () async {
    var searches = 0;
    final executor = EdgeIptvIntentExecutor(
      search: (_) async {
        searches++;
        return const [];
      },
      recentChannels: () async => [_channel('recent')],
    );

    final result = await executor.execute(
      IntentCommand(intent: MediaIntent.resume, sort: null, confidence: 0.9),
    );

    expect((result as IntentExecutionCompleted).resultIds, ['recent']);
    expect(searches, 0);
  });

  test('executor maps EPG programme results back to channel ids', () async {
    final executor = EdgeIptvIntentExecutor(
      search: (query) async => [
        LocalIptvSearchResult(
          type: LocalIptvSearchResultType.program,
          title: '$query Live',
          channelId: 'channel-1',
          rank: 0,
        ),
      ],
      recentChannels: () async => const [],
    );

    final result = await executor.execute(
      IntentCommand(
        intent: MediaIntent.browse,
        entities: const [
          IntentEntityValue(type: IntentEntityType.country, value: 'India'),
        ],
        sort: null,
        confidence: 0.9,
      ),
    );

    expect((result as IntentExecutionCompleted).resultIds, ['channel-1']);
  });

  test('configured pack installs once before offline parsing', () async {
    final edge = _FakeEdge(
      const IntentResult(
        intent: 'search',
        tool: 'media.search',
        confidence: 0.9,
        constraints: {'query': 'Aaj Tak'},
        missingFields: [],
        clarificationRequired: false,
      ),
    );
    final assistant = EdgeIptvAssistant(
      edge,
      executor: _RecordingExecutor(['aaj-tak']),
      channelById: (id) async => _channel(id),
      config: EdgeIptvConfig.fromValues(
        backend: 'native',
        packPath: '/packs/media.pack',
      ),
    );

    await assistant.resolveNaturalLanguage('Aaj Tak');
    await assistant.resolveNaturalLanguage('Aaj Tak');

    expect(edge.installedPaths, ['/packs/media.pack']);
    expect(edge.contexts, hasLength(2));
    expect(
      edge.contexts.every((context) => context.network == NetworkState.offline),
      isTrue,
    );
  });
}

EdgeIptvAssistant _assistant(_FakeEdge edge, IntentExecutor executor) {
  return EdgeIptvAssistant(
    edge,
    executor: executor,
    channelById: (id) async => _channel(id),
  );
}

IPTVChannel _channel(String id) => IPTVChannel(
  id: id,
  name: id,
  streamUrl: 'https://example.invalid/$id.m3u8',
  group: 'Test',
  category: ChannelCategory.general,
  flavor: ChannelFlavor.general,
  languages: const ['en'],
  sources: const ['test'],
);

final class _RecordingExecutor implements IntentExecutor {
  _RecordingExecutor(this.resultIds);

  final List<String> resultIds;
  final List<IntentCommand> commands = [];

  @override
  Future<IntentExecutionResult> execute(IntentCommand command) async {
    commands.add(command);
    return IntentExecutionCompleted(resultIds: resultIds);
  }
}

final class _FakeEdge implements EdgeIntelligence {
  _FakeEdge(this.intent) : failure = null;
  _FakeEdge.failure() : intent = null, failure = StateError('private failure');

  final IntentResult? intent;
  final Object? failure;
  final List<ExecutionContext> contexts = [];
  final List<String> installedPaths = [];

  @override
  Future<IntentResult> parseIntent(
    ExecutionContext context,
    ParseIntentQuery query,
  ) async {
    contexts.add(context);
    if (failure case final failure?) throw failure;
    return intent!;
  }

  @override
  Future<PackInstallResult> installPack(
    ExecutionContext context,
    InstallPackCommand command,
  ) async {
    installedPaths.add(command.packPath);
    return const PackInstallResult(
      packId: 'test',
      version: '1',
      activated: true,
    );
  }

  @override
  Future<SdkVersion> sdkVersion() async =>
      const SdkVersion(major: 0, minor: 2, patch: 2, abi: 0);

  @override
  Future<SearchResult> search(ExecutionContext context, SearchQuery query) =>
      throw UnimplementedError();
  @override
  Future<RecommendationResult> recommend(
    ExecutionContext context,
    RecommendationQuery query,
  ) => throw UnimplementedError();
  @override
  Future<ResolvedMedia> play(ExecutionContext context, PlayCommand command) =>
      throw UnimplementedError();
  @override
  Future<ResolvedMedia?> resume(ExecutionContext context, ResumeQuery query) =>
      throw UnimplementedError();
  @override
  Future<ResolvedMedia> resolve(ExecutionContext context, ResolveQuery query) =>
      throw UnimplementedError();
}
