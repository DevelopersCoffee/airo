import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../data/repositories/remote_agent_skill_store.dart';
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

  Future<AgentSkill> install(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw const FormatException('Skills must be loaded from an HTTPS URL.');
    }
    final document = await _fetcher(uri).timeout(const Duration(seconds: 15));
    if (utf8.encode(document).length > maxDocumentBytes) {
      throw const FormatException('Skill document exceeds the 256 KB limit.');
    }
    final skill = SkillManifestParser.parse(
      document,
      skillSource: SkillSource.remote,
      installState: SkillInstallState.disabled,
    );
    if (skill.id.isEmpty || skill.instructions.length < 8) {
      throw const FormatException('Skill document is incomplete.');
    }
    await _store?.saveDocument(document);
    return skill;
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
