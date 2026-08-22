import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../data/repositories/remote_agent_skill_store.dart';
import '../models/agent_plugin_catalog.dart';
import '../models/agent_skill.dart';
import 'skill_manifest_parser.dart';

typedef RemoteSkillDocumentFetcher = Future<String> Function(Uri uri);

/// Fetches a SKILL.md document without executing anything from the network.
/// Imported skills are quarantined (disabled) until the user explicitly
/// enables them in the Agent Skills screen.
class RemoteAgentSkillInstaller {
  RemoteAgentSkillInstaller({RemoteSkillDocumentFetcher? fetcher, this._store})
    : _fetcher = fetcher ?? _fetchOverHttps;

  static const maxDocumentBytes = RemoteAgentSkillStore.maxDocumentBytes;
  final RemoteSkillDocumentFetcher _fetcher;
  final RemoteAgentSkillStore? _store;

  Future<AgentSkill> install(
    String url, {
    SkillInstallState installState = SkillInstallState.disabled,
    String origin = 'url',
  }) async {
    final uri = resolveRemoteSkillDocumentUri(url);
    if (uri.scheme != 'https' || uri.host.isEmpty) {
      throw const FormatException('Skills must be loaded from an HTTPS URL.');
    }
    final document = await _fetcher(uri).timeout(const Duration(seconds: 15));
    if (utf8.encode(document).length > maxDocumentBytes) {
      throw const FormatException('Skill document exceeds the 256 KB limit.');
    }
    final skill = SkillManifestParser.parse(
      document,
      skillSource: SkillSource.remote,
      installState: installState,
    );
    if (skill.id.isEmpty || skill.instructions.length < 8) {
      throw const FormatException('Skill document is incomplete.');
    }
    await _store?.saveRecord(
      InstalledPluginRecord(
        id: skill.id,
        version: skill.version,
        document: document,
        sourceUrl: uri.toString(),
        origin: origin,
      ),
    );
    return skill;
  }

  Future<AgentSkill> installFromCatalog(AgentPluginCatalogEntry entry) {
    return install(
      entry.url,
      installState: SkillInstallState.enabled,
      origin: 'catalog',
    );
  }

  static Future<String> _fetchOverHttps(Uri uri) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.getUrl(uri);
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('Skill URL returned HTTP ${response.statusCode}.');
      }
      final bytes = await response.fold<List<int>>([], (buffer, chunk) {
        if (buffer.length + chunk.length > maxDocumentBytes) {
          throw const FormatException(
            'Skill document exceeds the 256 KB limit.',
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

/// Resolves a Gallery skill folder or GitHub tree URL to the SKILL.md document.
Uri resolveRemoteSkillDocumentUri(String url) {
  final parsed = Uri.tryParse(url.trim());
  if (parsed == null || parsed.scheme != 'https' || parsed.host.isEmpty) {
    throw const FormatException('Skills must be loaded from an HTTPS URL.');
  }

  final github = _githubRawSkillUri(parsed);
  if (github != null) return github;

  if (parsed.path.toLowerCase().endsWith('skill.md')) {
    return parsed;
  }
  final path = parsed.path.endsWith('/') ? parsed.path : '${parsed.path}/';
  return parsed.replace(path: '${path}SKILL.md');
}

Uri? _githubRawSkillUri(Uri uri) {
  if (uri.host != 'github.com') return null;
  final match = RegExp(
    r'^/([^/]+)/([^/]+)/(?:tree|blob)/([^/]+)/(.+?)(?:/SKILL\.md)?/?$',
    caseSensitive: false,
  ).firstMatch(uri.path);
  if (match == null) return null;
  final owner = match.group(1)!;
  final repo = match.group(2)!;
  final branch = match.group(3)!;
  final skillPath = match.group(4)!;
  return Uri.https(
    'raw.githubusercontent.com',
    '/$owner/$repo/$branch/$skillPath/SKILL.md',
  );
}
