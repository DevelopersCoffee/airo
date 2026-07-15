import 'package:flutter_test/flutter_test.dart';
import 'package:platform_channels/platform_channels.dart';

void main() {
  group('AiroLogoBurstPolicy', () {
    test('returns bounded candidates around the focused channel', () {
      const policy = AiroLogoBurstPolicy(
        lookBehind: 1,
        lookAhead: 4,
        maxCandidates: 3,
        maxCandidatesPerHost: 10,
      );

      final candidates = policy.precacheCandidates(_channels, 3);

      expect(candidates.map((channel) => channel.id), ['2', '3', '4']);
    });

    test('deduplicates logo URLs and caps each host', () {
      const policy = AiroLogoBurstPolicy(
        lookBehind: 0,
        lookAhead: 8,
        maxCandidates: 8,
        maxCandidatesPerHost: 2,
      );

      final candidates = policy.precacheCandidates([
        _channel('1', 'https://logos.example.com/a.png'),
        _channel('2', 'https://logos.example.com/b.png'),
        _channel('3', 'https://logos.example.com/c.png'),
        _channel('4', 'https://cdn.example.net/a.png'),
        _channel('5', 'https://cdn.example.net/a.png'),
      ], 0);

      expect(candidates.map((channel) => channel.id), ['1', '2', '4']);
    });

    test('skips invalid, blank, and non-http logo URLs', () {
      const policy = AiroLogoBurstPolicy(
        lookBehind: 0,
        lookAhead: 6,
        maxCandidates: 6,
        maxCandidatesPerHost: 6,
      );

      final candidates = policy.precacheCandidates([
        _channel('1', null),
        _channel('2', ''),
        _channel('3', 'file:///tmp/logo.png'),
        _channel('4', 'https://cdn.example.com/valid.png'),
      ], 0);

      expect(candidates.map((channel) => channel.id), ['4']);
    });

    test('handles empty lists and out-of-range focus indexes', () {
      const policy = AiroLogoBurstPolicy(
        lookBehind: 0,
        lookAhead: 1,
        maxCandidates: 2,
      );

      expect(policy.precacheCandidates(const [], 4), isEmpty);
      expect(
        policy.precacheCandidates(_channels, 99).map((channel) => channel.id),
        ['5'],
      );
    });
  });
}

final _channels = [
  _channel('0', 'https://logos0.example.com/logo.png'),
  _channel('1', 'https://logos1.example.com/logo.png'),
  _channel('2', 'https://logos2.example.com/logo.png'),
  _channel('3', 'https://logos3.example.com/logo.png'),
  _channel('4', 'https://logos4.example.com/logo.png'),
  _channel('5', 'https://logos5.example.com/logo.png'),
];

IPTVChannel _channel(String id, String? logoUrl) {
  return IPTVChannel(
    id: id,
    name: 'Channel $id',
    streamUrl: 'https://streams.example.com/$id.m3u8',
    logoUrl: logoUrl,
  );
}
