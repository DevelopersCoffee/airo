import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../models/agent_plugin_catalog.dart';

typedef PluginCatalogFetcher = Future<String> Function(Uri uri);

class AgentPluginCatalogLoader {
  AgentPluginCatalogLoader({
    this.bundledCatalog,
    PluginCatalogFetcher? fetcher,
    this.remoteUrl = defaultCatalogUrl,
    AssetBundle? bundle,
  }) : _fetcher = fetcher,
       _bundle = bundle;

  static const bundledAsset = 'skills/catalog.json';
  static const defaultCatalogUrl =
      'https://raw.githubusercontent.com/DevelopersCoffee/airo/main/packages/feature_mind/skills/catalog.json';

  final String? bundledCatalog;
  final PluginCatalogFetcher? _fetcher;
  final String remoteUrl;
  final AssetBundle? _bundle;

  Future<AgentPluginCatalog> load() async {
    final bundled = await _loadBundled();
    try {
      final remote = await _loadRemote();
      if (remote.entries.isNotEmpty) return remote;
    } catch (_) {
      if (bundled != null) return bundled;
      rethrow;
    }
    if (bundled != null) return bundled;
    return const AgentPluginCatalog([]);
  }

  Future<AgentPluginCatalog?> _loadBundled() async {
    if (bundledCatalog != null) {
      return AgentPluginCatalog.parse(bundledCatalog!);
    }
    try {
      final source = await (_bundle ?? rootBundle).loadString(bundledAsset);
      return AgentPluginCatalog.parse(source);
    } catch (_) {
      return null;
    }
  }

  Future<AgentPluginCatalog> _loadRemote() async {
    final uri = Uri.parse(remoteUrl);
    if (uri.scheme != 'https') {
      throw const FormatException('Plugin catalog must be loaded over HTTPS.');
    }
    final source = await (_fetcher ?? _fetchOverHttps)(uri);
    if (utf8.encode(source).length > AgentPluginCatalog.maxCatalogBytes) {
      throw const FormatException('Plugin catalog exceeds the 64 KB limit.');
    }
    return AgentPluginCatalog.parse(source);
  }

  static Future<String> _fetchOverHttps(Uri uri) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Catalog URL returned HTTP ${response.statusCode}.',
        );
      }
      final bytes = await response.fold<List<int>>([], (buffer, chunk) {
        if (buffer.length + chunk.length > AgentPluginCatalog.maxCatalogBytes) {
          throw const FormatException(
            'Plugin catalog exceeds the 64 KB limit.',
          );
        }
        return buffer..addAll(chunk);
      });
      return utf8.decode(bytes);
    } finally {
      client.close(force: true);
    }
  }
}
