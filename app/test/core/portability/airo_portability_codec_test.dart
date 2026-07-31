import 'dart:convert';

import 'package:airo_app/core/portability/airo_portability_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AiroPortabilityCodec', () {
    test(
      'decodes a versioned chat history entries list off the UI path',
      () async {
        final encoded = jsonEncode({
          'schemaVersion': 1,
          'entries': [
            {'role': 'user', 'text': 'hello'},
          ],
        });

        expect(
          await AiroPortabilityCodec.decodeChatHistory(encoded),
          equals([
            {'role': 'user', 'text': 'hello'},
          ]),
        );
      },
    );

    test(
      'returns null for missing, malformed, or incompatible history',
      () async {
        expect(await AiroPortabilityCodec.decodeChatHistory(null), isNull);
        expect(await AiroPortabilityCodec.decodeChatHistory('{broken'), isNull);
        expect(
          await AiroPortabilityCodec.decodeChatHistory(
            jsonEncode({'schemaVersion': 1, 'entries': 'not-a-list'}),
          ),
          isNull,
        );
      },
    );

    test(
      'encodes payload and chat history with explicit schema versions',
      () async {
        final payload = await AiroPortabilityCodec.encodePayload({
          'scope': 'airo-mind',
          'schemaVersion': 1,
        });
        final history = await AiroPortabilityCodec.encodeChatHistory([
          {'role': 'assistant', 'text': 'ready'},
        ], schemaVersion: 7);

        expect(jsonDecode(payload), {'scope': 'airo-mind', 'schemaVersion': 1});
        expect(jsonDecode(history), {
          'schemaVersion': 7,
          'entries': [
            {'role': 'assistant', 'text': 'ready'},
          ],
        });
      },
    );
  });
}
