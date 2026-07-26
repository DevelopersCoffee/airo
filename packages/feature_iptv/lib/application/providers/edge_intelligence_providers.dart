import 'dart:io';
import 'package:core_edge_intelligence/core_edge_intelligence.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:platform_playlist_import/platform_playlist_import.dart';
import 'package:slm_edge_intelligence/slm_edge_intelligence.dart';

import '../../domain/local_iptv_search.dart';
import 'iptv_providers.dart';
import 'local_iptv_search_providers.dart';

enum EdgeIptvBackend { ruleBased, nativeFfi }

final class EdgeIptvConfig {
  const EdgeIptvConfig({required this.backend, this.packPath, this.packAsset});

  final EdgeIptvBackend backend;
  final String? packPath;
  final String? packAsset;

  factory EdgeIptvConfig.fromEnvironment() {
    return EdgeIptvConfig.fromValues(
      backend: const String.fromEnvironment(
        'AIRO_EDGE_INTELLIGENCE_BACKEND',
        defaultValue: 'rule',
      ),
      packPath: const String.fromEnvironment('AIRO_MEDIA_PACK'),
      packAsset: const String.fromEnvironment('AIRO_MEDIA_PACK_ASSET'),
    );
  }

  factory EdgeIptvConfig.fromValues({
    required String backend,
    String? packPath,
    String? packAsset,
  }) {
    return EdgeIptvConfig(
      backend: switch (backend.trim().toLowerCase()) {
        'native' ||
        'native_ffi' ||
        'ffi' ||
        'pack' => EdgeIptvBackend.nativeFfi,
        _ => EdgeIptvBackend.ruleBased,
      },
      packPath: packPath == null || packPath.trim().isEmpty
          ? null
          : packPath.trim(),
      packAsset: packAsset == null || packAsset.trim().isEmpty
          ? null
          : packAsset.trim(),
    );
  }

  bool get shouldInstallPack =>
      (packPath != null && packPath!.isNotEmpty) ||
      (packAsset != null && packAsset!.isNotEmpty);
}

final edgeIptvConfigProvider = Provider<EdgeIptvConfig>((ref) {
  return EdgeIptvConfig.fromEnvironment();
});

final edgeIntelligenceProvider = Provider<EdgeIntelligence>((ref) {
  final config = ref.watch(edgeIptvConfigProvider);
  return switch (config.backend) {
    EdgeIptvBackend.ruleBased => EdgeIntelligence.ruleBased(),
    EdgeIptvBackend.nativeFfi => EdgeIntelligence.native(),
  };
});

final edgeIptvAssistantProvider = Provider<EdgeIptvAssistant>((ref) {
  return EdgeIptvAssistant(
    ref.watch(edgeIntelligenceProvider),
    config: ref.watch(edgeIptvConfigProvider),
    executor: EdgeIptvIntentExecutor(
      search: (query) async {
        final index = await ref.read(localIptvSearchIndexProvider.future);
        return index.search(query);
      },
      recentChannels: () => ref.read(recentlyWatchedChannelsProvider.future),
      structuredSearch: ref.watch(edgeIndexedIntentSearchProvider)?.call,
    ),
    channelById: (id) async {
      final channels = await ref.read(iptvChannelsProvider.future);
      for (final channel in channels) {
        if (channel.id == id) return channel;
      }
      return null;
    },
  );
});

/// Installed by playlist bootstrap after a native v2 descriptor is open.
final edgeIndexedIntentSearchProvider = Provider<IndexedPlaylistIntentSearch?>(
  (ref) => null,
);

final class EdgeIptvAssistant {
  EdgeIptvAssistant(
    this._edge, {
    required this.executor,
    required this.channelById,
    EdgeIptvConfig? config,
    Future<String?> Function(EdgeIptvConfig config)? packPathResolver,
    this.confidenceThreshold = 0.75,
  }) : _packPathResolver = packPathResolver ?? _resolveConfiguredPackPath,
       _config =
           config ?? const EdgeIptvConfig(backend: EdgeIptvBackend.ruleBased);

  final EdgeIntelligence _edge;
  final IntentExecutor executor;
  final Future<IPTVChannel?> Function(String id) channelById;
  final EdgeIptvConfig _config;
  final Future<String?> Function(EdgeIptvConfig config) _packPathResolver;
  final double confidenceThreshold;
  Future<PackInstallResult?>? _packInstall;

  Future<EdgeIptvResolution> resolveNaturalLanguage(String utterance) async {
    final stopwatch = Stopwatch()..start();
    final query = utterance.trim();
    if (query.isEmpty) {
      return EdgeIptvResolution(
        message: 'Enter a channel or request.',
        elapsed: stopwatch.elapsed,
      );
    }

    final context = _context();
    try {
      await _ensurePackInstalled(context);
      final intent = await _edge.parseIntent(context, ParseIntentQuery(query));
      final validation = IntentCommand.validateJson(_intentCommandJson(intent));
      if (validation case ValidIntentCommand(:final command)
          when command.confidence >= confidenceThreshold &&
              !intent.clarificationRequired) {
        final resolved = await _execute(command);
        if (resolved != null) {
          return EdgeIptvResolution(
            intent: intent,
            command: command,
            channel: resolved,
            elapsed: stopwatch.elapsed,
          );
        }
      }
      return _fallback(query, intent: intent, stopwatch: stopwatch);
    } on Object {
      return _fallback(query, stopwatch: stopwatch);
    }
  }

  Future<IPTVChannel?> _execute(IntentCommand command) async {
    final execution = await executor.execute(command);
    if (execution is! IntentExecutionCompleted || execution.resultIds.isEmpty) {
      return null;
    }
    return channelById(execution.resultIds.first);
  }

  Future<EdgeIptvResolution> _fallback(
    String query, {
    IntentResult? intent,
    required Stopwatch stopwatch,
  }) async {
    final command = IntentCommand(
      intent: MediaIntent.search,
      entities: [IntentEntityValue(type: IntentEntityType.title, value: query)],
      sort: null,
      confidence: 1,
    );
    final channel = await _execute(command);
    return EdgeIptvResolution(
      intent: intent,
      command: command,
      channel: channel,
      message: channel == null
          ? 'No local channel or programme matched.'
          : null,
      usedFallback: true,
      elapsed: stopwatch.elapsed,
    );
  }

  Future<void> _ensurePackInstalled(ExecutionContext context) async {
    final packPath = await _packPathResolver(_config);
    if (packPath == null || packPath.isEmpty) {
      return;
    }

    _packInstall ??= _edge.installPack(
      context,
      InstallPackCommand(packPath: packPath),
    );
    await _packInstall;
  }

  ExecutionContext _context() {
    return ExecutionContext(
      requestId: 'airo-${DateTime.now().microsecondsSinceEpoch}',
      locale: const LocaleContext(language: 'en', region: 'IN'),
      network: NetworkState.offline,
      deviceClass: 'tv',
      capabilities: const ['iptv', 'hls'],
    );
  }
}

Future<String?> _resolveConfiguredPackPath(EdgeIptvConfig config) async {
  if (config.packPath != null && config.packPath!.isNotEmpty) {
    return config.packPath;
  }
  final asset = config.packAsset;
  if (asset == null || asset.isEmpty) {
    return null;
  }

  final data = await rootBundle.load(asset);
  final supportDir = await getApplicationSupportDirectory();
  final fileName = _packAssetFileName(asset);
  final destination = File(
    '${supportDir.path}/edge_intelligence/packs/$fileName',
  );
  await destination.parent.create(recursive: true);
  await destination.writeAsBytes(data.buffer.asUint8List(), flush: true);
  return destination.path;
}

String _packAssetFileName(String asset) {
  final normalized = asset.replaceAll('\\', '/');
  final fileName = normalized.split('/').where((part) => part.isNotEmpty).last;
  return fileName.endsWith('.pack') ? fileName : '$fileName.pack';
}

final class EdgeIptvResolution {
  const EdgeIptvResolution({
    this.intent,
    this.command,
    this.channel,
    this.message,
    this.usedFallback = false,
    this.elapsed = Duration.zero,
  });

  final IntentResult? intent;
  final IntentCommand? command;
  final IPTVChannel? channel;
  final String? message;
  final bool usedFallback;
  final Duration elapsed;
}

Map<String, Object?> _intentCommandJson(IntentResult result) {
  final intent = switch (result.intent) {
    'recommend' => 'similar',
    'browse' || 'play' || 'resume' || 'search' => result.intent,
    _ => result.intent,
  };
  final entities = <Map<String, Object?>>[];
  final filters = <Map<String, Object?>>[];
  for (final entry in result.constraints.entries) {
    final value = entry.value;
    if (value == null) continue;
    final field = switch (entry.key) {
      'query' => 'title',
      'quality' || 'continue_watching' => 'tag',
      _ => entry.key,
    };
    if (field == 'title' && value is String) {
      entities.add({'type': 'title', 'value': value});
    } else if (_intentFilterFields.contains(field) &&
        (value is String || value is num || value is bool)) {
      filters.add({'field': field, 'operator': 'equals', 'value': value});
    }
  }
  return {
    'intent': intent,
    'entities': entities,
    'filters': filters,
    'sort': null,
    'confidence': result.confidence,
  };
}

const _intentFilterFields = {
  'title',
  'alias',
  'genre',
  'language',
  'country',
  'provider',
  'tag',
  'actor',
  'director',
  'studio',
  'collection',
  'live',
  'favorite',
  'year',
  'durationSeconds',
};

final class EdgeIptvIntentExecutor implements IntentExecutor {
  EdgeIptvIntentExecutor({
    required this.search,
    required this.recentChannels,
    this.structuredSearch,
  });

  final Future<List<LocalIptvSearchResult>> Function(String query) search;
  final Future<List<IPTVChannel>> Function() recentChannels;
  final Future<List<String>?> Function(IntentCommand command)? structuredSearch;

  @override
  Future<IntentExecutionResult> execute(IntentCommand command) async {
    if (command.intent == MediaIntent.resume) {
      final recent = await recentChannels();
      return IntentExecutionCompleted(
        resultIds: recent.isEmpty ? const [] : [recent.first.id],
      );
    }
    final nativeIds = await structuredSearch?.call(command);
    if (nativeIds != null) {
      return IntentExecutionCompleted(resultIds: nativeIds);
    }

    final terms = <String>{
      for (final entity in command.entities) entity.value,
      for (final filter in command.filters)
        if (filter.value case final String value when value.trim().isNotEmpty)
          value,
    };
    final ids = <String>[];
    for (final term in terms) {
      final results = await search(term);
      for (final result in results) {
        if (!ids.contains(result.channelId)) ids.add(result.channelId);
      }
    }
    return IntentExecutionCompleted(resultIds: ids);
  }
}

final class IndexedPlaylistIntentSearch {
  const IndexedPlaylistIntentSearch({
    required this.service,
    required this.descriptor,
  });

  final IndexedM3uPlaylistService service;
  final IndexedM3uPlaylistDescriptor descriptor;

  Future<List<String>?> call(IntentCommand command) async {
    if (command.sort != null) return null;
    final queryTerms = <String>[
      for (final entity in command.entities)
        if (entity.type == IntentEntityType.title ||
            entity.type == IntentEntityType.alias)
          entity.value,
    ];
    final filters = <IndexedPlaylistSearchFilter>[];
    for (final filter in command.filters) {
      final field = switch (filter.field) {
        IntentFilterField.title => IndexedPlaylistSearchField.title,
        IntentFilterField.alias => IndexedPlaylistSearchField.alias,
        IntentFilterField.genre => IndexedPlaylistSearchField.genre,
        IntentFilterField.language => IndexedPlaylistSearchField.language,
        IntentFilterField.country => IndexedPlaylistSearchField.country,
        IntentFilterField.provider => IndexedPlaylistSearchField.provider,
        IntentFilterField.tag => IndexedPlaylistSearchField.tag,
        _ => null,
      };
      final operator = switch (filter.operator) {
        IntentFilterOperator.equals => IndexedPlaylistSearchOperator.equals,
        IntentFilterOperator.contains => IndexedPlaylistSearchOperator.contains,
        _ => null,
      };
      final value = filter.value;
      if (field == null || operator == null || value is! String) return null;
      filters.add(
        IndexedPlaylistSearchFilter(
          field: field,
          operator: operator,
          value: value,
        ),
      );
    }
    for (final entity in command.entities) {
      final field = switch (entity.type) {
        IntentEntityType.genre => IndexedPlaylistSearchField.genre,
        IntentEntityType.language => IndexedPlaylistSearchField.language,
        IntentEntityType.country => IndexedPlaylistSearchField.country,
        IntentEntityType.provider => IndexedPlaylistSearchField.provider,
        IntentEntityType.tag => IndexedPlaylistSearchField.tag,
        _ => null,
      };
      if (field != null) {
        filters.add(
          IndexedPlaylistSearchFilter(
            field: field,
            operator: IndexedPlaylistSearchOperator.equals,
            value: entity.value,
          ),
        );
      }
    }
    final result = await service.searchV2(
      descriptor: descriptor,
      query: queryTerms.isEmpty ? null : queryTerms.join(' '),
      filters: filters,
      limit: 50,
    );
    return result?.channels
        .map((channel) => channel.id)
        .toList(growable: false);
  }
}
