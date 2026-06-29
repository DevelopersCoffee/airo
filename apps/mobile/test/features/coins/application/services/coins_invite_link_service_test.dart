import 'package:airo_app/features/coins/application/services/coins_invite_link_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CoinsInviteLinkService', () {
    test('builds cloud invite links with group and owner context', () {
      const service = CoinsInviteLinkService(
        baseUrl: 'https://example.com/coins/join',
      );

      final link = service.buildInviteLink(
        groupId: 'group_1',
        inviteCode: 'ABC12345',
        ownerUserId: 'user_1',
      );

      expect(link.toString(), contains('https://example.com/coins/join'));
      expect(link.queryParameters['groupId'], 'group_1');
      expect(link.queryParameters['invite'], 'ABC12345');
      expect(link.queryParameters['owner'], 'user_1');
      expect(link.queryParameters['mode'], 'cloud');
      expect(link.queryParameters['v'], '1');
    });

    test('extracts invite code from links and raw codes', () {
      const service = CoinsInviteLinkService();

      expect(
        service.extractInviteCode(
          'https://airo.app/coins/join?groupId=g1&invite=abc12345',
        ),
        'ABC12345',
      );
      expect(service.extractInviteCode('abc12345'), 'ABC12345');
    });
  });
}
