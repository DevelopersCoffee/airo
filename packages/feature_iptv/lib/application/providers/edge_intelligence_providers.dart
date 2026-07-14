import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:platform_channels/platform_channels.dart';
import 'package:slm_edge_intelligence/slm_edge_intelligence.dart';

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
  );
});

final class EdgeIptvAssistant {
  EdgeIptvAssistant(
    this._edge, {
    EdgeIptvConfig? config,
    Future<String?> Function(EdgeIptvConfig config)? packPathResolver,
  }) : _packPathResolver = packPathResolver ?? _resolveConfiguredPackPath,
       _config =
           config ?? const EdgeIptvConfig(backend: EdgeIptvBackend.ruleBased);

  final EdgeIntelligence _edge;
  final EdgeIptvConfig _config;
  final Future<String?> Function(EdgeIptvConfig config) _packPathResolver;
  Future<PackInstallResult?>? _packInstall;

  Future<EdgeIptvResolution> resolveNaturalLanguage(String utterance) async {
    final query = utterance.trim();
    if (query.isEmpty) {
      return const EdgeIptvResolution(message: 'Enter a channel or request.');
    }

    final context = _context();
    await _ensurePackInstalled(context);
    final intent = await _edge.parseIntent(context, ParseIntentQuery(query));

    if (intent.clarificationRequired) {
      return EdgeIptvResolution(
        intent: intent,
        message: 'Please ask for a specific channel, category, or title.',
      );
    }

    final media = await switch (intent.intent) {
      'resume' => _edge.resume(context, const ResumeQuery()),
      'play' => _edge.play(
        context,
        PlayCommand(query: _queryConstraint(intent) ?? query),
      ),
      'search' || 'browse' => _playTopSearchResult(context, query, intent),
      'recommend' => _playTopRecommendation(context, intent),
      _ => _playTopRecommendation(context, intent),
    };

    if (media == null) {
      return EdgeIptvResolution(
        intent: intent,
        message: 'No playable media was found.',
      );
    }

    return EdgeIptvResolution(intent: intent, media: media);
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

  Future<ResolvedMedia?> _playTopSearchResult(
    ExecutionContext context,
    String query,
    IntentResult intent,
  ) async {
    final result = await _edge.search(
      context,
      SearchQuery(text: query, constraints: intent.constraints, limit: 1),
    );
    if (result.candidates.isEmpty) {
      return null;
    }
    return _edge.resolve(context, ResolveQuery(result.candidates.first.id));
  }

  Future<ResolvedMedia?> _playTopRecommendation(
    ExecutionContext context,
    IntentResult intent,
  ) async {
    final result = await _edge.recommend(
      context,
      RecommendationQuery(constraints: intent.constraints, limit: 1),
    );
    if (result.candidates.isEmpty) {
      return null;
    }
    return _edge.resolve(context, ResolveQuery(result.candidates.first.id));
  }

  ExecutionContext _context() {
    return ExecutionContext(
      requestId: 'airo-${DateTime.now().microsecondsSinceEpoch}',
      locale: const LocaleContext(language: 'en', region: 'IN'),
      network: NetworkState.online,
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
  const EdgeIptvResolution({this.intent, this.media, this.message});

  final IntentResult? intent;
  final ResolvedMedia? media;
  final String? message;

  IPTVChannel? get channel {
    final resolved = media;
    if (resolved == null) {
      return null;
    }

    return IPTVChannel(
      id: resolved.id,
      name: resolved.title,
      streamUrl: resolved.streamUri.toString(),
      logoUrl: resolved.thumbnail?.toString(),
      group: _group(resolved.metadata),
      category: _category(resolved.metadata),
      flavor: _flavor(resolved.metadata),
      languages: [_language(resolved.metadata)],
      headers: _headers(resolved.headers),
      sources: const ['edge_intelligence'],
    );
  }
}

String? _queryConstraint(IntentResult intent) {
  final value = intent.constraints['query'];
  return value is String && value.trim().isNotEmpty ? value.trim() : null;
}

String _group(Map<String, Object?> metadata) {
  final genre = metadata['genre'];
  if (genre is String && genre.trim().isNotEmpty) {
    return genre.replaceAll('_', ' ');
  }
  return 'Edge Intelligence';
}

ChannelCategory _category(Map<String, Object?> metadata) {
  final genre = (metadata['genre'] as String?)?.toLowerCase();
  return switch (genre) {
    'news' => ChannelCategory.news,
    'business_news' => ChannelCategory.business,
    'sports' => ChannelCategory.sports,
    'movies' => ChannelCategory.movies,
    'kids' => ChannelCategory.kids,
    'music' => ChannelCategory.music,
    'religious' || 'devotional' => ChannelCategory.devotional,
    _ => ChannelCategory.general,
  };
}

ChannelFlavor _flavor(Map<String, Object?> metadata) {
  final genre = (metadata['genre'] as String?)?.toLowerCase();
  final language = (metadata['language'] as String?)?.toLowerCase();
  if (genre == 'news' && language == 'hi') {
    return ChannelFlavor.hindiNews;
  }
  if (genre == 'news' && language == 'en') {
    return ChannelFlavor.englishNews;
  }
  if (genre == 'music' && language == 'hi') {
    return ChannelFlavor.hindiMusic;
  }
  if (genre == 'music' && language == 'en') {
    return ChannelFlavor.englishMusic;
  }
  if (genre == 'movies') {
    return ChannelFlavor.movies;
  }
  if (genre == 'sports') {
    return ChannelFlavor.sports;
  }
  if (genre == 'kids') {
    return ChannelFlavor.kids;
  }
  if (genre == 'religious' || genre == 'devotional') {
    return ChannelFlavor.devotional;
  }
  return ChannelFlavor.general;
}

String _language(Map<String, Object?> metadata) {
  final value = metadata['language'];
  return value is String && value.trim().isNotEmpty ? value : 'en';
}

ChannelHeaders? _headers(Map<String, String> headers) {
  final userAgent = headers['User-Agent'] ?? headers['user-agent'];
  final referrer =
      headers['Referer'] ?? headers['Referrer'] ?? headers['referer'];
  if (userAgent == null && referrer == null) {
    return null;
  }
  return ChannelHeaders(userAgent: userAgent, referrer: referrer);
}
