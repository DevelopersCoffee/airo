class CoinsInviteLinkService {
  static const String defaultInviteBaseUrl = String.fromEnvironment(
    'AIRO_INVITE_BASE_URL',
    defaultValue: 'https://airo.app/coins/join',
  );

  const CoinsInviteLinkService({this.baseUrl = defaultInviteBaseUrl});

  final String baseUrl;

  Uri buildInviteLink({
    required String groupId,
    required String inviteCode,
    required String ownerUserId,
    bool cloudMode = true,
  }) {
    final base = Uri.parse(baseUrl);
    return base.replace(
      queryParameters: {
        ...base.queryParameters,
        'groupId': groupId,
        'invite': inviteCode,
        'owner': ownerUserId,
        'mode': cloudMode ? 'cloud' : 'local',
        'v': '1',
      },
    );
  }

  String extractInviteCode(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    final uri = Uri.tryParse(trimmed);
    final queryCode =
        uri?.queryParameters['invite'] ??
        uri?.queryParameters['code'] ??
        uri?.queryParameters['inviteCode'];
    if (queryCode != null && queryCode.trim().isNotEmpty) {
      return queryCode.trim().toUpperCase();
    }
    final segments = uri?.pathSegments ?? const <String>[];
    if (segments.isNotEmpty) {
      return segments.last.trim().toUpperCase();
    }
    return trimmed.toUpperCase();
  }
}
